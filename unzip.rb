require_relative 'cio.rb'
begin
    require 'zip'
rescue LoadError
    puts "[!] rubyzip not installed - not extracting archive. Install with `gem install rubyzip`"
    puts "[!] Zip files will not be auto-extracted."
    puts
end

# zip util
def unzip(zip_path)
    CIO.push
    content = []
    if defined?Zip
        CIO.puts "extracting zip #{zip_path} . . ."
        CIO.push
        Zip::File.open(zip_path) do |zip|
            zip.each do |file|
                path = zip_path.split(".")[0..-2].join(".").split("/")
                path[-1] = "ZIP_"+path[-1]
                path = File.join("#{path.join("/")}", file.name)
                FileUtils.mkdir_p(File.dirname(path))
                if File.exist?(path)
                    CIO.puts "skipped #{path} (file already exists)"
                else
                    CIO.puts "extracting #{path} . . ."
                    zip.extract(file, path)
                    content.append(file.name)
                end
            end
        end
        CIO.pop
    else
        CIO.puts "rubyzip not installed - not extracting archive. Install with `gem install rubyzip`"
    end
    CIO.pop
    return content
end