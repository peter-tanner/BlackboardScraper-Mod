# Blackboard Scraper

## Fork of [https://github.com/JaciBrunning/BlackboardScraper](https://github.com/JaciBrunning/BlackboardScraper) for UWA and NTU\* LMS

_\*I've briefly used the script on my exchange with NTU in 2023 but I do not guarantee that it still works today._

## Please use responsibly

Please do not redistribute content saved using this script! I've made this script strictly for saving content of courses I am enrolled in for my own learning, not to redistribute content illegally.

Obviously I do not store your login details, you may review `login.rb` to see how it works. I've opted to use a selenium instance since automating the MS login prompt is too hard.

### Why?

Becaues I prefer learning with the resources on a real filesystem (with the ability to copy/paste/etc.), rather than a web interface/app.

### Use

This tool allows you to quickly and easily dump all unit materials in Blackboard into a folder (`out`).

This tool downloads most unit materials, but will NOT download iLectures, announcements, grades or external links.

```bash
$ ruby scraper.rb  --help
Blackboard scraper
Usage: scraper.rb [options] (Revision a5a622384934d1047c8287fdcb22b3f4c72b2194)
    -u, --username=USERNAME          Automatically use provided userID
    -p, --path=PATH                  Path to download files to
        --cookie_file=FILE           Path to store cookie file at
    -g, --grades                     Download assessment and grade files
    -n, --ntu                        NTULearn mode
    -c, --community                  Download community pages instead of units
```

## Installation

- Download or clone this repository to somewhere on your system
- Install Ruby
  - Mac: should already be installed. Optionally install with Homebrew (`brew install ruby`)
  - Linux (Debian/Ubuntu): `apt-get install ruby-full`
  - Windows: [https://rubyinstaller.org/](https://rubyinstaller.org/)
- Install the `nokogiri` gem (Installing this gem on msys (Windows) doesn't work. Need to use WSL or something else.)
- Install the `rubyzip` gem (OPTIONAL - to automatically unzip any zip files downloaded)
- Install the `selenium-webdriver` gem - We need this to automate the Microsoft SSO/login.
  - An alternative way is to use an older version of BlackboardScraper which used python selenium webdriver.

  > `gem install nokogiri rubyzip selenium-webdriver`

- Install Chromedriver
  - For windows users see [this link](https://www.gregbrisebois.com/posts/chromedriver-in-wsl2/) (You do not need to install the graphics packages, as it can be run headless.)

## Usage

- Run the `scraper.rb` file:
  - `ruby scraper.rb` - It will ask for your Blackboard username (student ID) and password (and outlook 2FA prompt in the case of UWA), and will then work on its own, downloading course materials. It will take quite a while, and it's recommended to do it on a fast internet connection.
  - Here's a wrapper script I made around the scraper to make it easier to use and add live logging to catch errors (note that the ruby script does log to a file, but only if no errors occur):

  ```sh
  outpath="/mnt/d/BLACKBOARD"
  mkdir -p "$outpath"
  echo $@
  ruby {PATH/TO}/scraper.rb --grades --username {YOUR STUDENT ID} --path "$outpath" $@ 2>&1 | tee "$outpath/ZZZ_scraper_logs/$(date +'%Y-%m-%dT%H%M').log"
  ```

- Your course materials will now be in `out/`
- The script has a wait timer. Modify `$WAIT = 5` in `scraper.rb` to whatever seconds you want to wait between operations. This is to reduce stress on the server.

## NOTE

For units that like to have long folder/file names, you may find PDF readers or other applications fail to open the files and will promptly crash with no explanation. This is because the full path of the downloaded asset is longer than the system max filepath length (260 characters on windows, 1016 characters on macOS, 4096 on most linux distros).

Fix: move the file somewhere with a shorter path (like your Desktop, or Documents), or rename the files/folders after they have been downloaded to something less long.

Some directories and files may not be accessible on Windows since it may contain illegal characters such as ':'. I personally run it using WSL.
