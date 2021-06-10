require 'cgi'
require 'csv'
require 'fileutils'

require_relative 'utils.rb'
require_relative 'unzip.rb'
require_relative 'htmlunpack.rb'

# EXTENSIONS = [
#     /\.pdf$/, /\.docx$/, /\.txt$/, /\.c$/, /\.java$/, /\.class$/, /\.pptx$/, /\.ppt$/, /\.doc$/, /\.jar$/,
#     /\.java\..*$/, /\.class\..*$/, /\.csv/, /\.tar\.gz/
# ]

class BBAsset
    attr_accessor :session
    attr_accessor :hash
    attr_accessor :url
    attr_accessor :name
    attr_accessor :path

    def initialize session, pathhash, url, name, path
        @session = session
        @pathhash = pathhash
        @hash = ""
        @url = url
        @name = name
        @path = path
        @regular_asset = false

        @folder_metadata = "ZZZ_metadata"
        @folder_archive = "ZZZ_archive"
    end

    def setRegularAsset state
        @regular_asset = state
    end

    def fqp
        # "#{path}/#{friendly_filename(name)}_#{hash[0..6]}"
        "#{path}"
    end

    def download basepath, hidden_filename = true
        response = {}
        folder = "#{basepath}/#{fqp}"

        url = @url
        # If it contains cdn url don't change base url. (Cannot get filename from that temp. url)
        if !@regular_asset
            newurl = @session.doHead(url, false)["location"]
            unless (newurl.nil? || newurl.include?("blackboardcdn.com"))
                url = newurl
            end
        end

        head_cdn = @session.doHead(url, true)
        if ["404"].include?(head_cdn)
            CIO.puts colorize("-> Error "+head_cdn, "\e[31m")
            return {}
        end
        etag = head_cdn['etag'].undump
        @hash = Digest::MD5.hexdigest etag
        
        filename = File.basename(URI.parse(url).path)
        hfilename = conv_filename(filename)
        filepath = "#{folder}/#{hfilename}"
        metacsv_filepath = "#{folder}/#{@folder_metadata}/#{hfilename}__metadata.csv"

        hfilename_archive = conv_filename(filename, true)
        folder_archive = "#{folder}/#{@folder_archive}"
        filepath_archive = "#{folder_archive}/#{hfilename_archive}"
        metacsv_filepath_archive = "#{folder_archive}/#{@folder_metadata}/#{hfilename_archive}__metadata.csv"
        
        FileUtils.mkdir_p "#{folder}/#{@folder_metadata}"
        FileUtils.mkdir_p "#{folder_archive}/#{@folder_metadata}"

        download = false
        if !File.exists?(filepath)
            download = true
        else
            if File.exists?(metacsv_filepath)
                csv = CSV.read(metacsv_filepath)
                etag_meta = csv.find{|row| row[0] == 'etag'}[1]
                if etag_meta != etag
                    download = true
                end
            else
               download = true 
            end
        end

        if download
            # validext = !EXTENSIONS.reject { |x| filename.scan(x).empty? }.empty?
            # if validext
            File.open(filepath, 'wb') do |f|
                f.write @session.doGet(url).body
            end
            FileUtils.cp(filepath, filepath_archive)

            # Metadata info
            metacsv = [
                ["outside_blackboard",  (!@regular_asset).to_s],
                ["original_filename",   filename],
                ["readable_filename",   hfilename],
                ["url",                 url],
                ["pathhash",            @pathhash],
                ["etag",                etag],
                ["etaghash",            @hash],
                ["last-modified",       head_cdn["last-modified"]],
                ["content-length",      head_cdn["content-length"]],
                ["age",                 head_cdn["age"]],
            ]

            File.open(metacsv_filepath, 'wb') do |f|
                f.write(metacsv.map(&:to_csv).join)
            end
            FileUtils.cp(metacsv_filepath, metacsv_filepath_archive)

            response["name"] = to_s()
            # else
            #     CIO.puts "-> invalid extension, skipped: #{filename}"
            # end
        else
            CIO.puts "-> already downloaded!"
        end

        ext = File.extname(filename)
        case ext
        when ".zip"
            response["name"] = to_s()
            response["metacontent"] = unzip(filepath)
            if response["metacontent"].length == 0
                response = {}
            end
        when ".html", ".htm"
            response["name"] = to_s()
            # Rescrape these files to determine links...
            unpacker = HTMLUnpacker.new(@session, filepath)
            unpacker.parseLinks
            response["metacontent"] = unpacker.collectAssets
            if response["metacontent"].length == 0
                response = {}
            end
        end
        
        return response
    end

    def to_s
        "#{path}/#{name} (#{@pathhash})"
    end

    def conv_filename filename, etag = false
        filename = CGI.unescape(filename)
        ffilename_arr = friendly_filename(filename,$FILENAME_LEN).split(".")
        if $FILENAME_HASH_LEN > 0
            if etag 
                if ffilename_arr.length > 1
                    then "#{ffilename_arr[0..-2].join(".")}[#{@pathhash[0..$FILENAME_HASH_LEN]},#{@hash[0..$FILENAME_HASH_LEN]}].#{ffilename_arr[-1]}" 
                    else "#{ffilename_arr[0]}[#{@pathhash[0..$FILENAME_HASH_LEN]},#{@hash[0..$FILENAME_HASH_LEN]}]"
                end
            else
                if ffilename_arr.length > 1
                    then "#{ffilename_arr[0..-2].join(".")}[#{@pathhash[0..$FILENAME_HASH_LEN]}].#{ffilename_arr[-1]}"
                    else "#{ffilename_arr[0]}[#{@pathhash[0..$FILENAME_HASH_LEN]}]"
                end
            end
        else
            "#{ffilename_arr.join(".")}"
        end
    end
end