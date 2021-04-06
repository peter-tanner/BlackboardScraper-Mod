require_relative 'session.rb'
require 'optparse'
require 'fileutils'
require 'io/console'

options = {}
pass = ""
user = ""
OptionParser.new do |opts|
    opts.banner = "Usage: scraper.rb [options]"
    # opts.on("-p", "--password=PASSWORD", "Automatically use provided password") do |v|
    #     pass = v
    # end   # NOT SAFE DO NOT USE!!
    opts.on("-u", "--username=USERNAME", "Automatically use provided userID") do |v|
        user = v
    end
end.parse!

# $BASEPATH = "/mnt/f/ARCHIVE/UNIVERSITY/bb" # this is the path I normally use.
$BASEPATH = "../blackboard"
$COLOR = true           # Print color to terminal
$WAIT = 2               # To put less stress on the system.
$PATHNAME_LEN = 40      # Int - how many characters from the original path to keep (Cuts the length of paths down to prevent files from being inaccesible on systems)
$PATHNAME_HASH_LEN = 3
$FILENAME_LEN = -1      # -1 => unlimited length
$FILENAME_HASH_LEN = 5  # Int - how much of the file's hash to append on the end? Needed because files with the same name (but different content) can be downloaded.
                        # If 0, there's a risk that only one out of two or more files with the same filename but different content will be downloaded.

if !File.writable?($BASEPATH)
    if FileUtils.mkdir_p $BASEPATH
        puts "Created output directory #{$BASEPATH}"
    else
        puts "Cannot output to base directory #{$BASEPATH}. Do you have permissions?"
        exit 1
    end
end

session = BBSession.new user, pass
user = nil
pass = nil

# Fetch Units
CIO.puts
session.fetchUnits

# Discover Unit Sidebar Listings
CIO.puts
session.units.values.each(&:discover)

# Crawl Unit Listings (recursively enter listings)
CIO.puts
session.units.values.each(&:crawl)

# Report Status
CIO.puts
CIO.puts "Unit Report: "
CIO.with do 
    session.units.values.each do |unit|
        CIO.puts "#{unit.to_s}:"
        CIO.with do
            unit.listings.values.each do |listing|
                CIO.puts "#{listing.to_s}"
                CIO.with do
                    CIO.puts "(#{listing.collectAssets.values.size} asset(s))"
                end
            end
        end
    end
end

# Download Assets
downloaded = []

CIO.puts
CIO.puts colorize("Downloading Assets...","\e[1;33m")
CIO.with do 
    assets = session.units.values.map(&:collectAssets).map(&:values).flatten
    asset_count = assets.size
    assets.each_with_index do |asset, i|
        CIO.puts colorize("Downloading asset (#{i+1}/#{asset_count}): #{asset.to_s}", "\e[36m")
        response = asset.download $BASEPATH
        if response.length > 0
            downloaded.append(response)
        end
        sleep($WAIT)
    end
end

CIO.puts "FINISHED DOWNLOADING ITEMS!"

itemcount = downloaded.length
if downloaded.length > 0
    puts ""
    puts ""
    CIO.puts " - DOWNLOAD SUMMARY - "
    CIO.push
    downloaded.each_with_index do |f, i|
        if ( !f.key?("metacontent") )
            CIO.puts colorize("+ #{f["name"]}", "\e[32m")
        elsif ( f.key?("metacontent") && f["metacontent"].length > 0 )
            itemcount += f["metacontent"].length
            CIO.puts colorize("+ #{f["name"]}", "\e[32m")
            CIO.push
            f["metacontent"].each_with_index do |fz, j|
                CIO.puts colorize("+ #{fz}", "\e[32m")
            end
            CIO.pop
        end
    end
    CIO.puts colorize("Downloaded #{itemcount} items.", "\e[32m")
    print "Press any key to continue . . ."
    STDIN.getch
    puts ""
end