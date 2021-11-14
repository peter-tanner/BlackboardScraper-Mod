require 'nokogiri'
require 'csv'
require 'uri'

require_relative 'formats.rb'
require_relative 'asset.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'
require_relative 'utils.rb'
require_relative 'constants.rb'

class HTMLUnpacker

    def initialize session, filepath
        @filepath = filepath
        @downloadpath = @filepath.sub(/[.]htm[l]{0,1}$/,"__files")
        @metapath = @filepath.reverse.sub('/', '/'+METADATA_PREFIX.reverse+'/').reverse + METADATA_SUFFIX
        @session = session
        @assets = {}
    end
    
    def parseLinks
        CIO.puts colorize("-> Assets in file #{File.basename(@filepath)}","\e[1;33m")
        CIO.push

        csv = CSV.read(@metapath)
        file = File.read(@filepath)
        doc = Nokogiri::HTML(file)
        basepath = csv.find{|row| row[0] == 'url'}[1].match(/^.*\//)[0]
        
        doc.traverse do |el|
            [el[:src], el[:href]].grep(/\./).each do |link|
                link = clean_url(link)
                scheme = Formats.scheme(link)
                if ["http", "https"].include?(scheme)
                    if link.include?("/bbcswebdav")
                        fpath = link.sub(/^.*\/bbcswebdav/,"/bbcswebdav")
                        addAsset(fpath, fpath.sub(/.*\//, ""))
                    elsif Formats::WHITELIST.include?(File.extname(link).downcase)
                        addAsset(link, link.sub(/.*\//, ""))
                    else
                        CIO.puts "Etc. resource "+link+" - [1]skipped"
                        # # This can be anything like a YT link.
                    end
                elsif scheme == "relative" && ![".html", ".htm"].include?(File.extname(link).downcase)
                    fpath = File.join(basepath,link)
                    addAsset(fpath, link)
                end
            end
        end
        CIO.pop
    end

    def addRegularAsset link, title
        CIO.puts "-> Found Non-Blackboard Asset: "+title
        hash = Digest::MD5.hexdigest link
        asset = BBAsset.new(@session, hash, link, title, @downloadpath)
        asset.setRegularAsset(true)
        @assets[hash] = asset
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