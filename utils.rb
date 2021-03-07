def truncate(int,string)
    if string.length > int && int > 0
        string[0..int-1]
    else
        string
    end
end
def friendly_filename(filename, limit=$LIMIT_PATH_NAME)
    truncate(
        limit,
        filename.gsub(/[^[:print:]]/,'')#.gsub(/[^\w\s_-]+/, '')
            .gsub(/[\:\/\<\>\"\\\/\|\?\*]/,'')  # Windows forbidden characters.
            .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
            # .gsub(/\s+/, '_')
    )
end