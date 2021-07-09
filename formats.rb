module Formats
    def self.scheme url
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
        elsif url.match("^[A-Za-z]*:\/\/")
            nil
        else
            "relative"
        end
    end

    WHITELIST = [
        '.png',
        '.gif',
        '.jpg',
        '.jpeg',
        '.jfif',
        '.tga',
        '.targa',
        '.tif',
        '.tiff',
        '.bmp',
        '.ico',
        '.json',
        '.pdf',
        '.txt',
        '.zip',
        '.7z',
        '.tar',
        '.gz',
        '.lz',
        '.xml',
        '.svg',
        '.vdi',
        '.mov',
        '.wav',
        '.ogg',
        '.mp4',
        '.mp3',
        '.aac',
        '.csv',
        '.log',
        '.tex',
        '.rtf',
        '.docm',
        '.pub',
        '.xls',
        '.xlsx',
        '.doc',
        '.docx',
        '.thmx',
        '.ppt',
        '.pptx',
        '.css',
        '.js',
        '.jar',
        '.exe',
        '.c',
        '.cpp',
        '.h',
        '.java',
        '.class',
        '.rb',
        '.py',
        '.r',
        '.m',
        '.cs'
    ]
end