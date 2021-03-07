Blackboard Scraper (UWA)
========
## Fork of https://github.com/JaciBrunning/BlackboardScraper
## Use at own risk!

This tool allows you to quickly and easily dump all unit materials in Blackboard into a folder (`out/`).

This tool downloads most unit materials, but will NOT download iLectures, announcements, grades or external links.

## Installation
- Download or clone this repository to somewhere on your system  
- Install Ruby
    - Mac: should already be installed. Optionally install with Homebrew (`brew install ruby`)
    - Linux (Debian/Ubuntu): `apt-get install ruby-full`  
    - Windows: https://rubyinstaller.org/  
- Install the `nokogiri` gem  
    - `gem install nokogiri` in a shell terminal (this will take a while)  
    - Edit: Installing this gem on msys (Windows) doesn't work. Need to use WSL or something else.
- Download `chromedriver.exe` to this directory. Get it from https://chromedriver.chromium.org/.
- Install python 3
- Install selenium for python with `pip install selenium`. We need this to automate the Microsoft SSO/login.

## Usage
- Run the `scraper.rb` file:  
    - `ruby scraper.rb` - It will ask for your Blackboard username (UWA student ID) and password, and will then work on its own, downloading course materials. It will take quite a while, and it's recommended to do it on a fast internet connection.  
- Your course materials will now be in `out/`  
- The script has a wait timer. Modify `$WAIT = 10` in `scraper.rb` to whatever seconds you want to wait between operations. This is to reduce stress on the server.

## NOTE!
For units that like to have long folder/file names, you may find PDF readers or other applications fail to open the files and will promptly crash with no explanation. This is because the full path of the downloaded asset is longer than the system max filepath length (260 characters on windows, 1016 characters on macOS, 4096 on most linux distros). 

Fix: move the file somewhere with a shorter path (like your Desktop, or Documents), or rename the files/folders after they have been downloaded to something less long.