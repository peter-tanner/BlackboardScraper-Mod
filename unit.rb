require_relative 'content.rb'
require_relative 'contenttypes.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'
require_relative 'constants.rb'

class BBUnit
    attr_accessor :id
    attr_accessor :name
    attr_accessor :session
    attr_accessor :listings
    attr_accessor :path

    def initialize session, id, name, path
        @session = session
        @id = id
        @name = name
        @path = path

        @listings = {}
        @tools = {}
    end

    def getEnrolled dir, name
        request = "webapps/blackboard/execute/searchRoster?sortDir=ASCENDING&sortCol=column1&userInfoSearchKeyString=FIRSTNAME&userInfoSearchOperatorString=Contains&course_id=#{@id}&action=sort&courseId=#{@id}&editPaging=true&numResults=#{ENROL_GET_LIMIT}"
        enrolled_list = @session.doGet(request).body
        FileUtils.mkdir_p dir
        File.write("#{dir}/#{name}", enrolled_list)
    end

    def discover
        CIO.puts "Discovering Listings for Unit: #{to_s}...."
        CIO.push

        folder_name = path_name(name, id)
        # Write course metadata
        getEnrolled("#{$BASEPATH}/#{path}/#{COURSE_METADATA_DIRNAME}", "#{folder_name}#{ENROLLED_SUFFIX}")
        write_dir_metadata( 
                            "#{$BASEPATH}/#{path}",
                            folder_name,
                            COURSE_METADATA_DIRNAME,
                            [
                                ["original_directoryname", name],
                                ["readable_directoryname", folder_name],
                                ["id", id],
                                ["content_type", CONTENT_TYPE::UNIT],
                                ["path", path],
                            ]
                          )

        # Grades
        if $GRADES
            @listings[BLACKBOARD_TOOL_ID_GRADES] = BBContent.new(self, BLACKBOARD_TOOL_ID_GRADES, BLACKBOARD_GRADES_DIRNAME, "#{path}/#{folder_name}/#{BLACKBOARD_GRADES_DIRNAME}", CONTENT_TYPE::GRADES)
        end

        # Content
        html = @session.doGet("webapps/blackboard/execute/announcement?method=search&context=course_entry&course_id=#{id}").body
        page = Nokogiri::HTML(html)
        #TODO: Conflict detection for @listings entries ? (if contentid conflicts with toolid for example)
        page.css('ul#courseMenuPalette_contents li a').each do |listing|

            valid = false
            learningunitsids = listing['href'].scan(/displayLearningUnit.*\&content_id=([-_0-9]+)\&/)
            contentids = listing['href'].scan(/listContent.*\&content_id=([-_0-9]+)\&/)
            blankids = listing['href'].scan(/blankPage.*\&content_id=([-_0-9]+)\&/)
            toolids = listing['href'].scan(/\&tool_id=([-_0-9]+)/)

            unless contentids.empty?
                CIO.puts "Discovered Listing -> #{listing.text}.... valid! (Content)"
                contentid = contentids.last.first
                @listings[contentid] = BBContent.new(self, contentid, listing.text, "#{path}/#{folder_name}", CONTENT_TYPE::CONTENT)
                valid = true
            end
            
            unless blankids.empty?
                CIO.puts "Discovered Listing -> #{listing.text}.... valid! (BlankPage)"
                blankid = blankids.last.first
                @listings[blankid] = BBContent.new(self, blankid, listing.text, "#{path}/#{folder_name}", CONTENT_TYPE::BLANK_PAGE)
                valid = true
            end
            
            unless toolids.empty?
                CIO.puts "Discovered Listing -> #{listing.text}.... valid! (Tool)"
                toolid = toolids.last.first
                @listings[toolid] = BBContent.new(self, toolid, listing.text, "#{path}/#{folder_name}/#{BLACKBOARD_TOOLS_DIRNAME}", CONTENT_TYPE::TOOL)
                valid = true
            end
            
            unless learningunitsids.empty?
                CIO.puts "Discovered Listing -> #{listing.text}.... valid! (Learning Unit)"
                toolid = learningunitsids.last.first
                @listings[learningunitsids] = BBContent.new(self, toolid, listing.text, "#{path}/#{folder_name}/#{BLACKBOARD_TOOLS_DIRNAME}", CONTENT_TYPE::LEARNING_UNIT)
                valid = true
            end

            unless valid
                CIO.puts "Discovered Listing -> #{listing.text}.... INVALID (???)"
            end
        end

        # Groups
        page.css('ul#myGroups_contents>li').each do |group|
            groupids = group['id'].scan(/([-_0-9]+)/)
            unless groupids.empty?
                CIO.puts "Discovered Listing -> #{group.text}.... valid! (Group)"
                groupid = groupids.last.first
                @listings[groupid] = BBContent.new(self, groupid, group.text, "#{path}/#{folder_name}/#{BLACKBOARD_GROUPS_DIRNAME}", CONTENT_TYPE::GROUP)
            else
                CIO.puts "Discovered Listing -> #{group.text}.... INVALID (???)"
            end
        end
        CIO.pop
        CIO.puts
        sleep($WAIT)
    end

    def crawl
        CIO.puts "Crawling resources for Units: #{to_s}..."
        CIO.with { @listings.values.each(&:crawl) }
        CIO.puts
    end

    def collectAssets
        assets = {}
        @listings.each { |ck, cv| cv.collectAssets.each { |k, asset| assets[k] = asset } }
        assets
    end

    def to_s
        "#{name} (#{@id})"
    end
end