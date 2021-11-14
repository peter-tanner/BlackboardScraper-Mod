# TODO: Crawl group resources (low priority)
# TODO: Download discussions (low priority, who even uses discussions?)
class BBGroup
    def initialize content
        @content = content
    end

    def downloadMembers outfile
        unit = @content.unit
        # tabId can be empty it seems
        members = unit.session.doGet("webapps/portal/execute/tabs/tabAction?action=refreshAjaxModule&modId=_24_1&tabId=&course_id=#{unit.id}&group_id=#{@content.id}").body
        File.write(outfile, members)
    end
end