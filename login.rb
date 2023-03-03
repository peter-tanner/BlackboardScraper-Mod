require 'selenium-webdriver'
require 'io/console' 
require 'yaml'

class BBLogin

    def initialize username, password, cookie_file
        @cookie_file = cookie_file
        @username = username

        options = Selenium::WebDriver::Chrome::Options.new
        # options.add_argument('--no-sandbox')

        # NOTE: REQUIRED FOR DEBUGGING
        options.add_argument("--headless"); #open Browser in maximized mode
        # if DEBUG
        #     options.add_argument("--headless"); #open Browser in maximized mode
        # end

        @driver = Selenium::WebDriver.for :chrome, options: options
        @wait = Selenium::WebDriver::Wait.new(:timeout => 15)
    end
    
    ID_BOX_USERNAME  = "i0116"
    ID_BOX_PASSWORD  = "i0118"
    ID_DIV_USERERROR = 'usernameError'
    ID_DIV_PASSERROR = 'passwordError'
    ID_BUTTON_NEXT   = "idSIButton9"
    ID_BUTTON_DENY   = "idBtn_Back"

    TARGET_URL = 'https://lms.uwa.edu.au/ultra'
    LOGIN_ENTRYPOINT_URL = 'https://lms.uwa.edu.au/auth-saml/saml/'
    SUCC_URL = 'lms.uwa.edu.au'

    def tryCookie        
        cookies = nil
        begin
            cookies = File.open(@cookie_file)
        rescue
            puts 'Could not read cookie file.'
            puts 'Trying normal login.'
            @driver.get(TARGET_URL)
            return tryMSlogin()
        end
        
        @driver.get(LOGIN_ENTRYPOINT_URL) # Page which does not redirect to MS login.
        
        cookies = YAML.load(cookies)
        for cookie in cookies do
            @driver.manage.add_cookie(cookie)
        end
        @driver.get(TARGET_URL)
                
        begin
            @wait.until{@driver.current_url.include?(SUCC_URL)}
            writeCookieFile()
            return reformatCookie()
        rescue
            puts 'Could not get auth cookie - Cookie expired?'
            puts 'Trying normal login.'
            return tryMSlogin()
        end
    end

    def getCookie
        @driver.get(TARGET_URL)
        return tryMSlogin()
    end

    private def tryMSlogin
        if @username == nil
            print "Username: "
            # REGEX TO REMOVE BRACKETED PASTE MODE CHARACTERS.
            @username = gets.chomp.sub(/^\e\[200~/,'').sub(/\e\[201~$/,'')
            print "\n"
        end

        print "Password: "
        password = STDIN.getpass().sub(/^\e\[200~/,'').sub(/\e\[201~$/,'')
        print "\n"

        # begin
        clickElement(ID_BOX_USERNAME).send_keys(@username+"@student.uwa.edu.au").perform
        clickElement(ID_BUTTON_NEXT).perform
        puts "Entered username."
        
        begin
            clickElement(ID_BOX_PASSWORD).send_keys(password).perform
            password = nil
            clickElement(ID_BUTTON_NEXT).perform
            puts "Entered password."
        rescue
            # IF WE CANNOT ENTER THE PASSWORD, THEN THE USERNAME STEP HAS FAILED.
            printElement(ID_DIV_USERERROR)
            @driver.quit
            exit -1
        end

        clickElement(ID_BUTTON_DENY).perform
        # clickElement(BUTTON_NEXT).perform # IF you want to remember credentials, switch these comments
        
        begin
            @wait.until{@driver.current_url.include?(SUCC_URL)}
        rescue
            puts 'Could not get auth cookie - Invalid ID or password?'
            @driver.quit
            exit -1
        end

        if @cookie_file
            writeCookieFile()
        end
        
        return reformatCookie()
    end

    private def reformatCookie
        cookies = {}

        @driver.manage.all_cookies.each{ |c|
            cookies[c[:name]] = c[:value]
        }
        @driver.quit
        puts "Logged in successfully!"
        return cookies
    end

    private def writeCookieFile
        FileUtils.mkdir_p(File.dirname(@cookie_file))
        File.write(@cookie_file, YAML.dump(@driver.manage.all_cookies))
    end
  
    private def clickElement selector
        @wait.until{@driver.find_element(id: selector).displayed?}
        clickable = @driver.find_element(id: selector)
        return @driver.action
            .click(clickable)
    end

    private def printElement selector
        @wait.until{@driver.find_element(id: selector).displayed?}
        puts(@driver.find_element(id: selector).text)
    end

end
