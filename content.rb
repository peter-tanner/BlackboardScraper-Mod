require 'digest'
require 'csv'

require_relative 'asset.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'

class BBContent
    attr_accessor :id
    attr_accessor :name
    attr_accessor :unit
    attr_accessor :contents
    attr_accessor :assets
    attr_accessor :path

    @@contentids = []

    def initialize unit, id, name, path
        @unit = unit
        @id = id
        @name = name
        @path = path

        @contents = {}
        @assets = {}
    end

    def crawl
        sleep($WAIT)
        CIO.puts "Crawling Content: #{to_s}"
        CIO.push

        html = @unit.session.doGet("webapps/blackboard/content/listContent.jsp?course_id=#{@unit.id}&content_id=#{id}&mode=reset").body
        page = Nokogiri::HTML(html)

        folder_name = path_name(name, id)
        write_dir_metadata(
                            "#{$BASEPATH}/#{path}",
                            folder_name,
                            "ZZZ_folder_metadata",
                            [["original_directoryname", name],
                            ["readable_directoryname", folder_name],
                            ["id", id]]
                          )

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
                section.css("div.details div div ul.attachments li a")
                    .select { |x| x['href'].start_with?("/bbcswebdav") }
                    .each { |asset| addAsset(asset, sectionName) }

                section.css("div.item h3 a")
                    .select { |x| x['href'].start_with?("/bbcswebdav") }
                    .each { |asset| addAsset(asset, sectionName) }

                # I initially thought that this was bugged because this little block caused the files to be put into their own directory without a valid ID
                # But turns out the items are actually not inside of the folder (when you click on the folder with the content_id link, it says "There is no content to display.")
                # Instead, the items are placed in the description of the folder. So the scraper treats it as the same page (and not inside of the folder).
                # Kinda hard to explain but basically don't be alarmed if you see some items under folders that don't have a content_id on the end.
                section.css("div.details div div a")
                    .select { |x| x['href'].include?("/bbcswebdav") }
                    .each { |asset| 
                        asset['href'] = asset['href'].sub(/^.*\/bbcswebdav/,'/bbcswebdav')
                        addAsset(asset, sectionName) 
                    }
            end
        end

        CIO.pop
    end

    def addAsset asset, sectionName
        title = asset.text.strip
        CIO.puts "-> Found Asset: #{asset.text} in #{sectionName}"
        title = sectionName + "_" + title if title != sectionName
        hash = Digest::MD5.hexdigest asset['href']
        @assets[hash] = BBAsset.new(@unit.session, hash, asset['href'], title, "#{path}/#{path_name(name, id)}/#{sectionName}")
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
                if ck == "_1976775_1"
                    puts 'lab'
                end
            }
        }
        assets
    end

    def to_s
        "#{name} (#{@id})"
    end
end