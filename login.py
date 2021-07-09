
from selenium import webdriver
from selenium.webdriver.support import expected_conditions as ec
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
# For chrome stuff
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.chrome.options import Options
# ---
import os
import requests
import time
import getpass
import json
import re
import sys
import argparse

def try_cookie(driver):
    for entry in driver.get_log('performance'):
        parameters = json.loads(entry["message"])['message']['params']
        if (
            'documentURL' in  parameters.keys()
            and 'redirectResponse' in parameters.keys()
            and re.search(r'https://lms.uwa.edu.au/ultra', parameters['documentURL']) != None
        ):
            print(parameters['redirectResponse']['requestHeaders']['Cookie'])
            driver.quit()
            os.system("tmux detach")
            exit(0)


parser = argparse.ArgumentParser(description='Automated microsoft SSO login.')
# parser.add_argument("-p", "--password", help="Automatically use provided password", default="")
parser.add_argument("-u", "--username", help="Automatically use provided userID", default="")

args = parser.parse_args()
USERNAME = args.username
# PASSWORD = args.password
if len(USERNAME) == 0:
    print('UserID: ', file=sys.stderr)
    USERNAME = input()
USERNAME += '@student.uwa.edu.au'
# if len(PASSWORD) == 0:
print('Password: ', file=sys.stderr)
PASSWORD = getpass.getpass('')

BOX_USERNAME = (By.ID, "i0116")
BOX_PASSWORD = (By.ID, "i0118")
DIV_USERERROR = (By.ID, 'usernameError')
BUTTON_NEXT = (By.ID, "idSIButton9")
BUTTON_DENY = (By.ID, "idBtn_Back")

# find_element_safe = lambda name,timeout=30:WebDriverWait(driver, timeout).until(lambda x: x.find_element_by_id(name))
WaitClickable = lambda driver,locator:WebDriverWait(driver, 10).until(ec.element_to_be_clickable(locator))

# Feel free to modify if you're not using chrome as a webdriver. Need this to get the request headers (which include auth shit.)

CAPABILITIES = DesiredCapabilities.CHROME
CAPABILITIES['goog:loggingPrefs'] = {'performance': 'ALL'}
OPTIONS = Options()
OPTIONS.add_argument("--headless")
driver = webdriver.Chrome(
                            executable_path='chromedriver',
                            desired_capabilities=CAPABILITIES,
                            options=OPTIONS
                        )

# ---

driver.get('https://lms.uwa.edu.au/ultra')

try_cookie(driver)

WaitClickable(driver,BOX_USERNAME).send_keys(USERNAME)
WaitClickable(driver,BUTTON_NEXT).click()
print('Entered username.', file=sys.stderr)

try:
    WaitClickable(driver,BOX_PASSWORD).send_keys(PASSWORD)
    WaitClickable(driver,BUTTON_NEXT).click()
    print('Entered password.', file=sys.stderr)
except:
    print(WebDriverWait(driver, 1).until(ec.visibility_of_element_located(DIV_USERERROR)).text, file=sys.stderr)
    driver.quit()
    exit(2)

WaitClickable(driver,BUTTON_DENY).click()
# WaitClickable(driver,BUTTON_NEXT).click() #IF you want to remember credentials, switch these comments

try_cookie(driver)

print('Could not get auth cookie - Invalid ID or password?', file=sys.stderr)
driver.quit()
exit(1)