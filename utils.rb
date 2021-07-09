def truncate(int,string)
    if string.length > int && int > 0
        string[0..int-1]
    else
        string
    end
end
def friendly_filename(filename, limit=$PATHNAME_LEN)
    truncate(
        limit,
        filename.gsub(/[^[:print:]]/,'')#.gsub(/[^\w\s_-]+/, '')
            .gsub(/[\:\/\<\>\"\\\/\|\?\*]/,'')  # Windows forbidden characters.
            .gsub(/[.]([\\\/])/,'_\\1')  # cannot have a trailing dot for windows.
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            # .gsub(/\s+/, '_')
    )
end
def path_name(name, id)
    id_ = id.gsub(/_/,'')
    if $PATHNAME_HASH_LEN >= id_.length
        "#{friendly_filename(name)}[#{id_}]"
    else
        "#{friendly_filename(name)}[#{id.gsub(/_/,'').reverse()[1..$PATHNAME_HASH_LEN].reverse()}]"
    end
    # Negative because the ID is sequential and the first few numbers only change so often. Also start at idx 1 because last number is ALWAYS 1.
end

def write_dir_metadata(path, folder_name, metadata_folder_name, arr)
    FileUtils.mkdir_p "#{path}/#{metadata_folder_name}"
    File.open("#{path}/#{metadata_folder_name}/#{folder_name}__metadata.csv", 'wb') do |f|
        f.write arr.map(&:to_csv).join
    end
end

def colorize(str, color, color_enable=$COLOR)
    color_enable ? color+str+"\e[0m" : str
end

def clean_url(url)
    return url.strip.gsub(" ","%20").gsub("\\","/") #Lazy sub.
end