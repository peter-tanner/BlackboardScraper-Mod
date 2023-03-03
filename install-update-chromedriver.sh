mkdir -p chromedriver_install
cd chromedriver_install
version="$(curl https://chromedriver.storage.googleapis.com/LATEST_RELEASE)"
wget "https://chromedriver.storage.googleapis.com/$version/chromedriver_linux64.zip"
unzip chromedriver_linux64.zip
sudo mv chromedriver /usr/bin/chromedriver
sudo chown root:root /usr/bin/chromedriver
sudo chmod +x /usr/bin/chromedriver
cd ..
rm -rf chromedriver_install
