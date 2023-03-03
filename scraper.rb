#!/usr/bin/ruby

require_relative 'session.rb'
require_relative 'constants.rb'

require 'optparse'
require 'fileutils'
require 'io/console'
require 'date'

# DISABLE BUFFER SINCE THIS IS A CONSOLE APPLICATION.
STDOUT.sync = true

script_dir = File.expand_path(__dir__)
CIO.puts "Blackboard scraper (Revision #{`git -C '#{script_dir}' rev-parse HEAD`.strip}) #{`git -C '#{script_dir}' status --porcelain`.strip.empty?() ? "" : "[DEV MODE]"}"

options = {}
password = nil
username = nil
cookie_file = nil
$BASEPATH = "../blackboard"
$GRADES = false
OptionParser.new do |opts|
    opts.banner = "Usage: scraper.rb [options]"
    # opts.on("-p", "--password=PASSWORD", "Automatically use provided password") do |v|
    #     password = v
    # end   # NOT SAFE DO NOT USE!! - shows in top, etc.
    opts.on("-u", "--username=USERNAME", "Automatically use provided userID") do |v|
        username = v
    end
    opts.on("-p", "--path=PATH", "Path to download files to") do |v|
        $BASEPATH = v
    end
    opts.on("-c", "--cookie_file=FILE", "Path to store cookie file at") do |v|
        cookie_file = v
    end
    opts.on("-g", "--grades", "Download assessment and grade files") do |v|
        $GRADES = v
    end
end.parse!

# $BASEPATH = "/mnt/f/ARCHIVE/UNIVERSITY/bb" # this is the path I normally use.
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

session = BBSession.new username, password, cookie_file
username = nil
password = nil

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

ERROR_LIST = [
    Errno::EINVAL, Errno::ECONNRESET, EOFError,
    Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
]

begin
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
rescue *ERROR_LIST => e
    CIO.puts "HTTP ERROR #{e}. Stop download."
# rescue StandardError => e
#     CIO.puts e
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
    CIO.save "#{$BASEPATH}/#{SCRAPER_LOGS_DIRNAME}/#{DateTime.now.strftime('%Y-%m-%dT%H%M')}.log"
    print "Press any key to continue . . ."
    STDIN.getch
    puts ""
end
