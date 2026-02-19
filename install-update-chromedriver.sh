#!/bin/bash

# Create installation directory
mkdir -p chromedriver_install
cd chromedriver_install

# Get the current Google Chrome version
chrome_version=$(google-chrome --version | grep -oP "\d+\.\d+\.\d+\.\d+")

# Extract the URL for the matching Chrome version
download_url=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json \
| jq -r --arg prefix "${chrome_version%.*}" '
  .channels | to_entries[]
  | .value.downloads.chromedriver[]
  | select(.url | contains($prefix))
  | select(.platform == "linux64")
  | .url
' | sort -V | tail -n1)

if [ -z "$download_url" ]; then
  echo "No matching download URL found for Chrome version $chrome_version"
  cd ..
  rm -rf chromedriver_install
  exit 1
fi

# Download the Chrome driver
wget "$download_url" -O chromedriver_linux64.zip

# Unzip the downloaded file
unzip chromedriver_linux64.zip

cd chromedriver-linux64

# Move the chromedriver to /usr/bin
sudo mv chromedriver /usr/bin/chromedriver

cd ..

# Set proper permissions
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver

# Cleanup
cd ..
rm -rf chromedriver_install

echo "ChromeDriver installed successfully for Chrome version $chrome_version"
