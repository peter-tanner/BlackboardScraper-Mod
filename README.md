# Blackboard Scraper

## Fork of https://github.com/JaciBrunning/BlackboardScraper

## Use at own risk!

### Why?

Becaues I prefer learning with the resources on a real filesystem (with the ability to copy/paste/etc.), rather than a web interface/app.

### Use

This tool allows you to quickly and easily dump all unit materials in Blackboard into a folder (`out`).

This tool downloads most unit materials, but will NOT download iLectures, announcements, grades or external links.

## Installation

- Download or clone this repository to somewhere on your system
- Install Ruby
  - Mac: should already be installed. Optionally install with Homebrew (`brew install ruby`)
  - Linux (Debian/Ubuntu): `apt-get install ruby-full`
  - Windows: https://rubyinstaller.org/
- Install the `nokogiri` gem (Installing this gem on msys (Windows) doesn't work. Need to use WSL or something else.)
- Install the `rubyzip` gem (OPTIONAL - to automatically unzip any zip files downloaded)
- Install the `selenium-webdriver` gem - We need this to automate the Microsoft SSO/login.

  - An alternative way is to use an older version of BlackboardScraper which used python selenium webdriver.

  > `gem install nokogiri rubyzip selenium-webdriver`

- Install Chromedriver
  - For windows users see [this link](https://www.gregbrisebois.com/posts/chromedriver-in-wsl2/) (You do not need to install the graphics packages, as it can be run headless.)

## Usage

- Run the `scraper.rb` file:
  - `ruby scraper.rb` - It will ask for your Blackboard username (student ID) and password, and will then work on its own, downloading course materials. It will take quite a while, and it's recommended to do it on a fast internet connection.
- Your course materials will now be in `out/`
- The script has a wait timer. Modify `$WAIT = 5` in `scraper.rb` to whatever seconds you want to wait between operations. This is to reduce stress on the server.

## NOTE!

For units that like to have long folder/file names, you may find PDF readers or other applications fail to open the files and will promptly crash with no explanation. This is because the full path of the downloaded asset is longer than the system max filepath length (260 characters on windows, 1016 characters on macOS, 4096 on most linux distros).

Fix: move the file somewhere with a shorter path (like your Desktop, or Documents), or rename the files/folders after they have been downloaded to something less long.
