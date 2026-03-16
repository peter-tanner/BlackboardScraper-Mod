require 'selenium-webdriver'
require 'io/console' 
require 'yaml'

class BBLoginNTU

    def initialize username, password, cookie_file, persistent_session_dir
        @cookie_file = cookie_file
        @username = username

        options = Selenium::WebDriver::Chrome::Options.new

        if persistent_session_dir
            options.add_argument("--user-data-dir=#{persistent_session_dir}")
        end

        # options.add_argument('--no-sandbox')

        # NOTE: REQUIRED FOR DEBUGGING
        options.add_argument("--headless"); #open Browser in maximized mode
        # if DEBUG
        #     options.add_argument("--headless"); #open Browser in maximized mode
        # end

        @driver = Selenium::WebDriver.for :chrome, options: options
        @wait = Selenium::WebDriver::Wait.new(:timeout => 15)
    end
    
    ID_BOX_USERNAME  = "userNameInput"
    ID_BOX_PASSWORD  = "passwordInput"


    ID_DIV_USERERROR = 'usernameError'
    ID_DIV_PASSERROR = 'passwordError'
    ID_BUTTON_NEXT   = "submitButton"

    TARGET_URL = 'https://ntulearn.ntu.edu.sg/?new_loc=/ultra/course'
    LOGIN_ENTRYPOINT_URL = 'https://ntulearn.ntu.edu.sg/auth-saml/'
    SUCC_URL = 'ntulearn.ntu.edu.sg'

    def tryCookie        
        cookies = nil
        @driver.get(LOGIN_ENTRYPOINT_URL) # Page which does not redirect to MS login.
        if @cookie_file
            begin
                cookies = File.open(@cookie_file)
            rescue
                puts 'Could not read cookie file.'
                puts 'Trying normal login.'
                @driver.get(TARGET_URL)
                return tryMSlogin()
            end
            
            cookies = YAML.load(cookies)
            for cookie in cookies do
                @driver.manage.add_cookie(cookie)
            end
        end
        
        @driver.get(TARGET_URL)
                
        begin
            @wait.until{@driver.current_url.include?(SUCC_URL)}
        rescue Exception => e
            puts 'Could not get auth cookie - Cookie expired?'
            puts "Trying normal login. (#{e})"
            return tryMSlogin()
        end
        
        writeCookieFile()
        return reformatCookie()
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
        clickElement(ID_BOX_USERNAME).send_keys(@username).perform
        clickElement(ID_BOX_PASSWORD).send_keys(password).perform
        password = nil
        clickElement(ID_BUTTON_NEXT).perform
        puts "Entered username and passsword."
        
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
        if @cookie_file
            FileUtils.mkdir_p(File.dirname(@cookie_file))
            File.write(@cookie_file, YAML.dump(@driver.manage.all_cookies))
        end
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
