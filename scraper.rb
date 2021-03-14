require_relative 'session.rb'
require 'pp'
require 'fileutils'
require 'io/console'

# ARGUMENTS

$BASEPATH = "out"
$WAIT = 5               # To put less stress on the system.
$PATHNAME_LEN = 40      #Int - how many characters from the original path to keep (Cuts the length of paths down to prevent files from being inaccesible on systems)
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
        CIO.puts "Downloading asset (#{i+1}/#{asset_count}): #{asset.to_s}"
        asset.download $BASEPATH
        sleep($WAIT)
    end
end