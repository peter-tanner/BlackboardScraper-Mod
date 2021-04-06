require 'nokogiri'
require 'csv'
require 'uri'

require_relative 'asset.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'

class HTMLUnpacker
    
    METADATA_PREFIX = 'ZZZ_metadata'
    METADATA_SUFFIX = '__metadata.csv'

    def initialize session, filepath
        @filepath = filepath
        @downloadpath = @filepath.sub(/[.]htm[l]{0,1}$/,"__files")
        @metapath = @filepath.reverse.sub('/', '/'+METADATA_PREFIX.reverse+'/').reverse + METADATA_SUFFIX
        @session = session
        @assets = {}
    end

    def scheme url
        if url.include?("https://")
            "https"
        elsif url.include?("http://")
            "http"
        elsif url.include?("mailto:")
            "mailto"
        elsif url.include?("file:///")
            "file"
        elsif url.include?("ftp://")
            "ftp"
        else
            nil
        end
    end

    def parseLinks
        CIO.puts colorize("-> Assets in file #{File.basename(@filepath)}","\e[1;33m")
        CIO.push

        csv = CSV.read(@metapath)
        file = File.read(@filepath)
        doc = Nokogiri::HTML(file)
        basepath = csv.find{|row| row[0] == 'url'}[1].match(/^.*\//)[0]
        
        doc.css("* a[href]")
            .each { |asset|
                link = asset['href'].strip.gsub(" ","%20").gsub("\\","/") #Lazy sub.
                if ["http", "https"].include?(scheme(link))
                    if link.include?("/bbcswebdav")
                        fpath = link.sub(/^.*\/bbcswebdav/,"/bbcswebdav")
                        addAsset(fpath, fpath.sub(/.*\//, ""))
                    else
                        # # This can be anything like a YT link.
                        # puts "Etc. resource "+link
                    end
                elsif scheme(link) == nil && ![".html", ".htm"].include?(File.extname(link))
                    fpath = File.join(basepath,link)
                    addAsset(fpath, link)
                end
            }
        CIO.pop
    end

    def addAsset link, title
        CIO.puts "-> Found Asset: "+title
        hash = Digest::MD5.hexdigest link
        @assets[hash] = BBAsset.new(@session, hash, link, title, @downloadpath)
    end

    def collectAssets
        CIO.puts colorize("-> Downloading Assets from file #{File.basename(@filepath)}...","\e[1;33m")
        CIO.push
        i = 0
        asset_count = @assets.size
        content = []
        for asset in @assets do
            i += 1
            CIO.puts colorize("Downloading asset (#{i}/#{asset_count}): #{asset[1].to_s}", "\e[36m")
            response = asset[1].download "."
            if response.length > 0
                content.append(asset[1].name)
            end
            sleep($WAIT)
        end
        CIO.pop
        return content
    end
end