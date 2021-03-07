require_relative 'session.rb'
require 'pp'
require 'fileutils'
require 'io/console'

# To put less stress on the system.
$WAIT = 1
$LIMIT_PATH_NAME = 24 #Int - how many characters from the original path to keep (Cuts the length of paths down to prevent files from being inaccesible on systems)
$FILENAME_HASH_LEN = 5  # Int - how much of the file's hash to append on the end? Needed because files with the same name (but different content) can be downloaded.
                        # If 0, there's a risk that only one out of two or more files with the same filename but different content will be downloaded.
$SHOW_FULL_FILE_PATH = true # Bool - override $LIMIT_PATH_NAME variable for filenames, keep full name for readability.
$BASEPATH = "out"

# CIO.puts "Username:"
# user = gets.chomp

# CIO.puts "Password:"
# pass = STDIN.noecho(&:gets).chomp

session = BBSession.new #user, pass

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
CIO.puts
CIO.puts "Downloading Assets..."
CIO.with do 
    assets = session.units.values.map(&:collectAssets).map(&:values).flatten
    asset_count = assets.size
    assets.each_with_index do |asset, i|
        CIO.puts "Downloading asset (#{i}/#{asset_count}): #{asset.to_s}"
        asset.download $BASEPATH
        sleep($WAIT)
    end
end