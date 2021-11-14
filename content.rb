require 'digest'
require 'pp'
require 'csv'
require 'fileutils'

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
    
    SELECTORS = [
        ["div.details * *[href]",   "href"],
        ["div.details * img[src]",  "src"]
    ]

    def initialize unit, id, name, path, contentType=CONTENT_TYPE::CONTENT
        @unit = unit
        @id = id
        @name = name
        @path = path
        @contentType = contentType

        @contents = {}
        @assets = {}
    end

    def crawl
        sleep($WAIT)
        CIO.puts "Crawling Content: #{to_s}"
        CIO.push

        request = ""
        case @contentType
        when CONTENT_TYPE::CONTENT
            request = "webapps/blackboard/content/listContent.jsp?course_id=#{@unit.id}&content_id=#{id}&mode=reset"
        when CONTENT_TYPE::TOOL
            request = "webapps/blackboard/content/launchLink.jsp?course_id=#{@unit.id}&tool_id=#{id}&tool_type=TOOL&mode=view&mode=reset"
        when CONTENT_TYPE::GROUP
            request = "webapps/blackboard/execute/modulepage/viewGroup?course_id=#{unit.id}&group_id=#{id}"
        else
            raise "Error - invalid content type."
        end

        html = @unit.session.doGet(request).body
        page = Nokogiri::HTML(html)

        unit_path = "#{$BASEPATH}/#{path}"
        folder_name = path_name(name, id)
        write_dir_metadata(
                            unit_path,
                            folder_name,
                            FOLDER_METADATA_DIRNAME,
                            [["original_directoryname", name],
                            ["readable_directoryname", folder_name],
                            ["id", id]]
                          )

        FileUtils.mkdir_p "#{unit_path}/#{folder_name}"
        File.write("#{unit_path}/#{folder_name}/#{BLACKBOARD_PAGE_FILE}", html) # TODO: Need to add stuff to download assets from these pages.

        if @contentType == CONTENT_TYPE::GROUP
            group = BBGroup.new(self)
            group.downloadMembers("#{unit_path}/#{folder_name}/#{BLACKBOARD_GROUP_FILE}")
        end

        page.css("ul#content_listContainer li div.item h3 a").select { |x| x['href'].start_with?("/webapps/blackboard/content") && !x['href'].include?("launchAssessment.jsp?") }.each do |listing|
            CIO.puts "-> Found Content: #{listing.text}"
            # CIO.puts "#{listing}"
            CIO.push            
            contentid = listing['href'].scan(/\&content_id=([-_0-9]+)/).last.first
            unless contentid == @id || @@contentids.include?(contentid)
                @contents[contentid] = BBContent.new(unit, contentid, listing.text, "#{path}/#{folder_name}")
                @@contentids << contentid
                @contents[contentid].crawl
            else
                CIO.puts "[ content not added (recursive) ]"
            end
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
                for selector in SELECTORS do
                    attribute = selector[1]
                    section.css(selector[0])
                        .select { |x| x[attribute].include?("/bbcswebdav") }
                        .each { |asset| 
                            # pp asset
                            asset[attribute] = asset[attribute].sub(/^.*\/bbcswebdav/,'/bbcswebdav')
                            addAsset(asset[attribute], asset.text, sectionName) 
                        }
                end
            end
        end

        CIO.pop
    end

    def addAsset link, text, sectionName
        if text.empty?
            text = "NULL"
        end
        title = text.strip
        CIO.puts "-> Found Asset: #{text} in #{sectionName}"
        title = sectionName + "_" + title if title != sectionName
        hash = Digest::MD5.hexdigest link
        @assets[hash] = BBAsset.new(@unit.session, hash, link, title, "#{path}/#{path_name(name, id)}/#{sectionName}")
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