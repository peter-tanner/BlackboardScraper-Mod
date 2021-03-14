require 'cgi'
require 'csv'

require_relative 'utils.rb'
require_relative 'unzip.rb'

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

    def initialize session, hash, url, name, path
        @session = session
        @hash = hash
        @url = url
        @name = name
        @path = path
    end

    def fqp
        # "#{path}/#{friendly_filename(name)}_#{hash[0..6]}"
        "#{path}"
    end

    def download basepath
        response = {}
        folder_metadata = "ZZZ_metadata"
        folder = "#{basepath}/#{fqp}"
        FileUtils.mkdir_p "#{folder}/#{folder_metadata}"

        url = @url
        head = @session.doHead(url)
        url = head["location"][1..-1] unless (head["location"].nil?)
        
        filename = File.basename(URI.parse(url).path)
        hfilename = conv_filename(filename)
        filepath = "#{folder}/#{hfilename}"
        unless File.exists? filepath
            # validext = !EXTENSIONS.reject { |x| filename.scan(x).empty? }.empty?
            # if validext
            File.open(filepath, 'wb') do |f|
                f.write @session.doGet(url).body
            end

            # Metadata info
            File.open("#{folder}/#{folder_metadata}/#{hfilename}__metadata.csv", 'wb') do |f|
                f.write [
                    ["original_filename", filename],
                    ["readable_filename", hfilename],
                    ["url", url],
                    ["hash", hash],
                ].map(&:to_csv).join
            end

            response["name"] = to_s()
            # else
            #     CIO.puts "-> invalid extension, skipped: #{filename}"
            # end
        else
            CIO.puts "-> already downloaded!"
        end

        if filename.split(".")[-1] == "zip"
            response["name"] = to_s()
            response["zip_content"] = unzip(filepath)
        end
        
        return response
    end

    def to_s
        "#{path}/#{name} (#{hash})"
    end

    def conv_filename filename
        filename = CGI.unescape(filename)
        ffilename_arr = friendly_filename(filename,$FILENAME_LEN).split(".")
        if $FILENAME_HASH_LEN > 0
            ffilename_arr.length > 1 ? "#{ffilename_arr[0..-2].join(".")}[#{hash[0..$FILENAME_HASH_LEN]}].#{ffilename_arr[-1]}" : "#{ffilename_arr[0]}[#{hash[0..$FILENAME_HASH_LEN]}]"
        else
            "#{ffilename_arr.join(".")}"
        end
    end
end