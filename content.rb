require 'digest'
require 'pp'
require 'csv'
require 'fileutils'
require 'cgi'
require 'json'

require_relative 'asset.rb'
require_relative 'group.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'
require_relative 'contenttypes.rb'
require_relative 'constants.rb'

class BBContent
    attr_accessor :id
    attr_accessor :name
    attr_accessor :unit
    attr_accessor :contents
    attr_accessor :assets
    attr_accessor :path
    attr_accessor :contentType

    @@contentids = []
    
    CONTENT_SELECTORS = [
        ["div.details * *[href]",       "href"],
        ["div.details * img[src]",      "src"],
        ["div.details * video[src]",    "src"],
    ]
    BLANK_PAGE_SELECTORS = [
        ["* *[href]",       "href"],
        ["* img[src]",      "src"],
        ["* video[src]",    "src"],
    ]

    def initialize unit, id, name, path, contentType=CONTENT_TYPE::CONTENT, request=nil
        @unit = unit
        @id = id
        @name = name
        @path = path
        @contentType = contentType
        @request = request

        @contents = {}
        @assets = {}
    end

    def addContent unit, contentid, listing_text, content_path, content_type, request=nil
        unless contentid == @id || @@contentids.include?(contentid)
            @contents[contentid] = BBContent.new(unit, contentid, listing_text, content_path, content_type, request)
            @@contentids << contentid
            @contents[contentid].crawl
        else
            CIO.puts "[ content not added (recursive) ]"
        end
    end


    def crawl
        sleep($WAIT)
        CIO.puts "Crawling Content: #{to_s}"
        CIO.push

        if @request == nil
            case @contentType
            when CONTENT_TYPE::BLANK_PAGE
                @request = "webapps/blackboard/execute/content/blankPage?cmd=view&course_id=#{@unit.id}&content_id=#{id}&mode=reset"
            when CONTENT_TYPE::CONTENT
                @request = "webapps/blackboard/content/listContent.jsp?course_id=#{@unit.id}&content_id=#{id}&mode=reset"
            when CONTENT_TYPE::TOOL
                @request = "webapps/blackboard/content/launchLink.jsp?course_id=#{@unit.id}&tool_id=#{id}&tool_type=TOOL&mode=view&mode=reset"
            when CONTENT_TYPE::GRADES
                @request = "webapps/blackboard/content/launchLink.jsp?course_id=#{@unit.id}&tool_id=#{BLACKBOARD_TOOL_ID_GRADES}&tool_type=TOOL&mode=view&mode=reset"
            when CONTENT_TYPE::GROUP
                @request = "webapps/blackboard/execute/modulepage/viewGroup?course_id=#{unit.id}&group_id=#{id}"
            else
                raise "Error - invalid content type."
            end
        end

        html = @unit.session.doGet(@request).body
        page = Nokogiri::HTML(html)

        unit_path = "#{$BASEPATH}/#{path}"
        folder_name = path_name(name, id)
        write_dir_metadata(
                            unit_path,
                            folder_name,
                            FOLDER_METADATA_DIRNAME,
                            [
                                ["original_directoryname", name],
                                ["readable_directoryname", folder_name],
                                ["id", id],
                                ["content_type", contentType],
                                ["path", path],
                            ]
                          )

        FileUtils.mkdir_p "#{unit_path}/#{folder_name}"
        File.write("#{unit_path}/#{folder_name}/#{BLACKBOARD_PAGE_FILE}", html) # TODO: Need to add stuff to download assets from these pages.
        
        case @contentType
        when CONTENT_TYPE::GROUP
            group = BBGroup.new(self)
            group.downloadMembers("#{unit_path}/#{folder_name}/#{BLACKBOARD_GROUP_FILE}")
        when CONTENT_TYPE::GRADES
            page.css("a[onclick]").each do |listing|
                onclick_action = listing['onclick']
                if onclick_action.include?("/webapps")
                    link = onclick_action.match(/loadContentFrame\('(.*)'\)/)[1]
                    parameters = CGI.parse(URI.parse(link).query)
                    if link.include?("/webapps/assignment/uploadAssignment") && parameters['action'].first == "showHistory"
                        addContent(unit, parameters['outcome_id'].first, listing.text, "#{path}/#{folder_name}", CONTENT_TYPE::UPLOAD_ASSIGNMENT, link)
                    elsif link.include?("/webapps/gradebook/do/student/viewAttempts")
                        addContent(unit, parameters['outcome_id'].first, listing.text, "#{path}/#{folder_name}", CONTENT_TYPE::VIEW_ATTEMPTS, link)
                    end
                end
            end
        when CONTENT_TYPE::VIEW_ATTEMPTS
            page.css("div#containerdiv.container.clearfix a[href]").each do |attempt|
                link = attempt['href']
                if link.include?("/webapps/assessment/review/review.jsp")
                    parameters = CGI.parse(URI.parse(link).query)
                    addContent(unit, parameters['attempt_id'].first, "ATTEMPT_#{parameters['attempt_id'].first}", "#{path}/#{folder_name}", CONTENT_TYPE::REVIEW_ATTEMPT, link)
                end
            end
        when CONTENT_TYPE::BLANK_PAGE, CONTENT_TYPE::UPLOAD_ASSIGNMENT, CONTENT_TYPE::REVIEW_ATTEMPT
            # It is too hard to scan a blank page since the user can define what ever structure they want for it. Just pick every href that starts with /bbcswebdav
            page.css("div#containerdiv.container.clearfix").each do |section|
                for selector in BLANK_PAGE_SELECTORS do
                    attribute = selector[1]
                    section.css(selector[0])
                    .select { |x| x[attribute].include?("/bbcswebdav") }
                    .each { |asset| 
                        asset[attribute] = asset[attribute].sub(/^.*\/bbcswebdav/,'/bbcswebdav')
                        addAsset(asset[attribute], asset.text, "NULL_SECTION") 
                    }
                end
            end
        end

        if @contentType == CONTENT_TYPE::UPLOAD_ASSIGNMENT
            # GET SUBMITTED FILES
            page.css("div#containerdiv.container.clearfix a[href]").each do |attempt|
                link = attempt['href']
                if link.include?("/webapps/assignment/download")
                    # ?course_id=_67971_1&attempt_id=_11878820_1&file_id=_3554419_1&fileName=red_training.bin
                    parameters = CGI.parse(URI.parse(link).query)
                    addAsset(link, parameters["fileName"].first, "SUBMITTED", true) 
                end
            end
            
            # GET FEEDBACK FILES
            page.css("body script").each do |script|
                if script.text.include?("gradeAssignment.init")
                    file_request = script.text.match(/gradeAssignment.init\(.*[,][ ]{0,}'(.*)'\)/)
                    if file_request.length > 1 && file_request[1].length > 0
                        file_request_json = JSON.parse(file_request[1])
                        if file_request_json["status"] != "UNSUPPORTED"
                            uuid = file_request_json['viewUuid'].sub(/--bav--/,"")
                            ticket = CGI.parse(URI.parse(file_request_json['viewUrl']).query)['ticket'][0]
                            jwt = @unit.session.doPost("https://annotate-ecs-au.foundations.blackboard.com/api/v1/pdfviewer/tickets",
                                                    {}, JSON.dump({"ticket"=>ticket}), "application/json").body
                            jwt = JSON.parse(jwt)["jwt"]
                            url = "https://annotate-ecs-au.foundations.blackboard.com/documents/#{uuid}/pdf?jwt=#{jwt}"
                            addAsset(url, file_request_json["fileName"], "FEEDBACK", true, uuid) 
                        else
                            CIO.puts "-> Unsupported feedback file #{file_request_json["fileName"]}."
                        end
                    else
                        CIO.puts "-> No feedback found."
                    end
                end
            end
        end

        
        page.css("ul#content_listContainer li div.item h3 a").select { |x| x['href'].start_with?("/webapps/blackboard/content") && !x['href'].include?("launchAssessment.jsp?") }.each do |listing|
            CIO.puts "-> Found Content: #{listing.text}"
            # CIO.puts "#{listing}"
            CIO.push            
            contentid = listing['href'].scan(/\&content_id=([-_0-9]+)/).last.first
            
            type = CONTENT_TYPE::CONTENT
            if listing['href'].include? "blankPage"
                type = CONTENT_TYPE::BLANK_PAGE
            end
            
            addContent(unit, contentid, listing.text, "#{path}/#{folder_name}", type)
            CIO.pop
        end
        
        page.css("ul#content_listContainer li").each do |section|
            h3 = section.css("div.item h3")
            unless h3.empty?
                sectionName = h3.first.text.strip
                # section.css("div.details div div ul.attachments li a")
                #     .select { |x| x['href'].start_with?("/bbcswebdav") }
                #     .each { |asset| addAsset(asset["href"], asset.text, sectionName) }    #Redundant because of the last expression.
                
                # Leads to another subfolder
                section.css("div.item h3 a")
                .select { |x| x['href'].start_with?("/bbcswebdav") }
                .each { |asset| addAsset(asset["href"], asset.text, sectionName) }
                
                # I initially thought that this was bugged because this little block caused the files to be put into their own directory without a valid ID
                # But turns out the items are actually not inside of the folder (when you click on the folder with the content_id link, it says "There is no content to display.")
                # Instead, the items are placed in the description of the folder. So the scraper treats it as the same page (and not inside of the folder).
                # Basically don't be alarmed if you see some items under folders that don't have a [content_id] on the end.
                for selector in CONTENT_SELECTORS do
                    attribute = selector[1]
                    section.css(selector[0])
                    .select { |x| x[attribute].include?("/bbcswebdav") }
                    .each { |asset| 
                        asset[attribute] = asset[attribute].sub(/^.*\/bbcswebdav/,'/bbcswebdav')
                        addAsset(asset[attribute], asset.text, sectionName) 
                    }
                end
            end
        end
        CIO.pop
    end

    def addAsset link, text, sectionName, feedback_asset = false, feedback_id = nil
        if text.empty?
            text = "NULL"
        end
        title = text.strip
        CIO.puts "-> Found Asset: #{text} in #{sectionName}"
        title = sectionName + "_" + title if title != sectionName
        hash = feedback_id ? Digest::MD5.hexdigest(feedback_id) : Digest::MD5.hexdigest(link)
        @assets[hash] = BBAsset.new(@unit.session, hash, link, title, "#{path}/#{path_name(name, id)}/#{sectionName}", feedback_asset)
    end

    def collectAssets
        assets = {}
        @assets.each { |k, asset| assets[k] = asset }
        @contents.each {    # Recursive folder traversal bs.
            |ck, cv| cv.contents.each { 
                |k, content| assets = assets.merge(content.collectAssets)
            }
        }
        @contents.each {
            |ck, cv| cv.assets.each {
                |k, asset| assets[k] = asset
            }
        }
        assets
    end

    def to_s
        "#{name} (#{@id})"
    end
end