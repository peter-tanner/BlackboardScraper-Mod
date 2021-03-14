require_relative 'content.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'

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
    end

    def discover
        CIO.puts "Discovering Listings for Unit: #{to_s}...."
        CIO.push

        folder_name = path_name(name, id)
        write_dir_metadata( 
                            "#{$BASEPATH}/#{path}",
                            folder_name,
                            "ZZZ_course_metadata",
                            [["original_unitname", name],
                            ["readable_unitname", folder_name],
                            ["id", id]]
                          )

        html = @session.doGet("webapps/blackboard/execute/announcement?method=search&context=course_entry&course_id=#{id}").body
        page = Nokogiri::HTML(html)

        page.css('ul#courseMenuPalette_contents li a').each do |listing|

            contentids = listing['href'].scan(/\&content_id=([-_0-9]+)\&/)
            unless contentids.empty?
                CIO.puts "Discovered Listing -> #{listing.text}.... valid!"
                contentid = contentids.last.first
                @listings[contentid] = BBContent.new(self, contentid, listing.text, "#{path}/#{folder_name}")
            else
                CIO.puts "Discovered Listing -> #{listing.text}.... valid!"
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