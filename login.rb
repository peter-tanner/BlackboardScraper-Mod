require 'selenium-webdriver'
require 'io/console' 

class BBLogin

    def initialize
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument("--headless"); #open Browser in maximized mode

        @driver = Selenium::WebDriver.for :chrome, options: options
        @wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    end
    
    ID_BOX_USERNAME  = "i0116"
    ID_BOX_PASSWORD  = "i0118"
    ID_DIV_USERERROR = 'usernameError'
    ID_DIV_PASSERROR = 'passwordError'
    ID_BUTTON_NEXT   = "idSIButton9"
    ID_BUTTON_DENY   = "idBtn_Back"

    def getCookie username, password
        @driver.get('https://lms.uwa.edu.au/ultra')

        # begin
        clickElement(ID_BOX_USERNAME).send_keys(username+"@student.uwa.edu.au").perform
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
            @wait.until{@driver.current_url.include?('https://lms.uwa.edu.au/ultra')}
        rescue
            puts 'Could not get auth cookie - Invalid ID or password?'
            @driver.quit
            exit -1
        end

        cookies = {}
        @driver.manage.all_cookies.each{ |c|
            cookies[c[:name]] = c[:value]
        }
        @driver.quit
        puts "Logged in successfully!"
        return cookies
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