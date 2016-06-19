=begin
Plugin: MyFitnessPal Logger
Description: Logs your MyFitnessPal diary
Author: [Matt Foster](https://hackerific.net)
Configuration:
  service_username: mattpfoster877
  tags: '#personal #fitness'
Notes:
  - Downloads your MFP data for today, then converts to Markdown using Marky. For this to work, your diary must be public.
=end

config = { 
  'description' => ['MyFitnessPal Logger',
                    'Your diary must be public. Set at http://www.myfitnesspal.com/account/diary_settings' ],
  'service_username' => '', 
  'tags' => '#personal #fitness' 
}
$slog.register_plugin({ 'class' => 'MFPLogger', 'config' => config })

require 'nokogiri'
require 'rest-client'

class MFPLogger < Slogger
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      config = @config[self.class.name]
      # check for a required key to determine whether setup has been completed or not
      if !config.key?('service_username') || config['service_username'] == []
        @log.warn("MyFitnessPal has not been configured or an option is invalid, please edit your slogger_config file.")
        return
      else
        # set any local variables as needed
        username = config['service_username']
      end
    else
      @log.warn("MyFitnessPal has not been configured or data is not public, please edit your slogger_config file.")
      return
    end

    @log.info("Logging MyFitnessPal diary data for #{username}")

    tags = config['tags'] || ''

    today = @timespan

    url = build_report_url(username, today.strftime('%Y-%m-%d'))
    logs = grab(url)

    entry  = "## MyFitnessPal daily report\n\n"
    entry +="User: [#{username}](http://www.myfitnesspal.com/food/diary/#{username})\n"

    logs.each do |name, table|
      entry += "\n### " + name.to_s.capitalize
      entry += to_md(table)
    end
    entry += "\n\n#{tags}"

    DayOne.new.to_dayone({ 'content' => entry })

  end

  def build_report_url(
    username,
    date,
    baseurl = 'http://www.myfitnesspal.com/reports/printable_diary/'
  )
    baseurl + username + '?from=' + date + '&to=' + date
  end

  def grab(url)
    doc = Nokogiri::HTML(open(url))

    if doc.to_s.include?('This Username is Invalid')
      abort "No data, check username is correct and diary is public"
    end

    log = {}
    log[:food] = doc.css('table#food').to_s
    # Note: the div name is spelt wrong!
    log[:exercise] = doc.css('table#excercise').to_s

    log
  end

  def to_md(str)
    to_md_url = 'http://fuckyeahmarkdown.com/go/'
    conv = RestClient.post(to_md_url, :html => str)
    conv.to_str
  end
end
