require "net/http"
# require "resolv-replace"
require "uri"
require "base64"
require "nokogiri"

require_relative 'unit.rb'
require_relative 'utils.rb'
require_relative 'cio.rb'
require_relative 'login.rb'
require_relative 'constants.rb'

class BBSession

    attr_accessor :units
    attr_accessor :http

    def initialize username, password, cookie_file
        # @user = username
        # @password = Base64.encode64(password)
        # @pwd_unicode = Base64.encode64(password.split("").product(["\x00"]).flatten.join("").force_encoding("US-ASCII")).strip

        @loginPL = {
            # user_id: @user,
            password: "",
            login: "Login",
            action: "login",
            'remote-user': "",
            new_loc: "",
            auth_type: "",
            one_time_token: "",
            # encoded_pw: @password.strip,
            # encoded_pw_unicode: @pwd_unicode
        }
        @cookies = {}

        @baseurl = "https://lms.uwa.edu.au"
        @trusted_domain = "uwa.edu.au"
        @uri = URI.parse(@baseurl)
        @http = Net::HTTP.new(@uri.host, @uri.port)

        @units = {}

        # password = nil
        # username = nil
        # cookie_string = `python3 login.py#{pyargs}`.strip
        # puts cookie_string
        # pyargs = nil
        # c = cookie_string.split('; ')
        # c.each{ |c|
        #     @cookies[c.split('=')[0]] = c.split('=')[1]
        # }

        mslogin = BBLogin.new username, password, cookie_file
        if cookie_file
            @cookies = mslogin.tryCookie
        else 
            @cookies = mslogin.getCookie
        end
        if @cookies.length == 0
            puts 'Login error. Check your credentials. Exiting scraper.'
            exit -1
        end
    end

    def set_request req, uri
        # FIXME: FACILITATE HTTP CONNECTIONS WHICH DON'T USE SSL
        if uri.host[-@trusted_domain.length..] == @trusted_domain
            req["Cookie"] = @cookies.map { |k,v| "#{k}=#{v}" }.join(";")
        else
            req["Cookie"] = ""
        end
        req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36'
    end

    def doPost path, payload, raw_data=nil, content_type=nil
        uri = URI.parse(path)
        if !(["http", "https"].include?(uri.scheme))
            uri = makeURI(path)
        end
        http_ = Net::HTTP.new(uri.host, uri.port)
        http_.use_ssl = uri.scheme == 'https'
        
        req = Net::HTTP::Post.new(uri.request_uri)
        req.set_form_data payload 
        req["Content-Length"] = req.body.length
        set_request(req, uri)
        if raw_data
            req.body = raw_data
        end
        if content_type
            req.content_type = content_type 
        end

        res = http_.request req
        cookies = res.get_fields('set-cookie')
        if cookies
            cookies.each { |cookie|
                c = cookie.split(';')[0]
                @cookies[c.split('=')[0]] = c.split('=')[1]
            }
        end
        res
    end

    def doRequest path, redirects = true, mode="get"
        uri = URI.parse(path)
        if ["http", "https"].include?(uri.scheme)
            http_ = Net::HTTP.new(uri.host, uri.port)
        else
            uri = makeURI(path)
            http_ = @http
        end
        http_ = Net::HTTP.new(uri.host, uri.port)
        http_.use_ssl = uri.scheme == 'https'

        req = case mode
            when "get"  then Net::HTTP::Get.new(uri.request_uri)
            when "head" then Net::HTTP::Head.new(uri.request_uri)
        end
        set_request(req, uri)
        while 1
            begin
                resp = http_.request req
                if redirects && resp.code == "302" && !resp['location'].empty?
                    return doRequest(resp['location'], true, mode)   # This is because blackboard serves the file over CDN. The webdav link redirects to a generated CDN link.
                elsif ["404"].include?(resp.code)
                    return resp.code
                else
                    return resp
                end
            rescue Net::OpenTimeout => e
                puts e
                sleep 5
                next
            rescue => e
                raise e
            end
        end

    end

    def doGet path, redirects = true
        doRequest(path, redirects, "get")
    end

    def doHead path, redirects = true
        doRequest(path, redirects, "head")
    end

    # def doHead path
    #     uri = makeURI(path)
    #     req = Net::HTTP::Head.new(uri.request_uri)
    #     req["Cookie"] = @cookies.map { |k,v| "#{k}=#{v}" }.join(";")
    #     req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36'
    #     @http.request req
    # end

    def makeURI path
        URI.join(@baseurl,path)
    end

    def fetchUnits
        puts "Fetching Units...."
        CIO.push

        # html = doGet("webapps/portal/execute/tabs/tabAction?action=refreshAjaxModule&modId=_4_1&tabId=_1_1&tab_tab_group_id=_1_1").body # use for community pages!
        html = doGet("webapps/portal/execute/tabs/tabAction?action=refreshAjaxModule&modId=_3_1&tabId=_1_1&tab_tab_group_id=_1_1").body
        page = Nokogiri::HTML(html)
        @units = Hash[page.css('ul.courseListing li a').map do |el|
            tmp = el['href'].scan(/\&id=([-_0-9]+)\&/)
            unless tmp.empty?
                courseid = tmp.last.first
                course = el.text
                []
                if COURSE_FILTER == nil || COURSE_FILTER.include?(courseid)
                    CIO.puts "Found Unit -> #{courseid} (#{course})"
                    [courseid, BBUnit.new(self, courseid, course, "")]
                else
                    [0,0]
                end
            else
                [0,0]
            end
        end]
        @units.delete(0)

        CIO.pop
    end
end