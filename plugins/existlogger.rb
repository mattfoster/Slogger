=begin
Plugin: Exist Logger
Description: Logs your Exist data
Author: [Matt Foster](https://hackerific.net)
Configuration:
  redirect_uri: 'oAuth2 redirect URI'
  client_id: 'oAuth2 client ID'
  client_secret: 'oAuth2 client secret'
  access_token: 'oAuth2 access token'
  tags: '#personal #fitness'
Notes:
  - Downloads your Exist data for today, and saves all attributes.
=end

config = { 
  'description' => [
    'Exist.io Logger',
    'https://exist.io' 
  ],
  'redirect_uri'  => "https://hackerific.net/slogger/exist/",
  'client_id'     => 'd26998cab3eaa34d5aca',
  'client_secret' => 'e854ed9aa67b1b4680734035dba6aa475b621a4e',
  'tags'          => '#personal #fitness'
}
$slog.register_plugin({ 'class' => 'ExistLogger', 'config' => config })

require 'rest-client'
require 'json'

class ExistLogger < Slogger
  # @config is available with all of the keys defined in "config" above
  # @timespan and @dayonepath are also available
  # returns: nothing
  def do_log
    if @config.key?(self.class.name)
      @exist_config = @config[self.class.name]
    else
      @log.warn("Exist has not been configured. Please authenticate by running on the command line.")
      return
    end

    # We need to have seen one run to have empty config, then we need to get a token
    if ! @exist_config.key?('access_token')
      return user_auth
    end

template = <<END
## Exist data for <%= username %>

<% attributes.each do |attr| %>
### <%= attr.label %>

| Item | Value | Source |
|------|-------|--------|
<% attr.items.each do |item| -%>
| <%= item.label %> | <%= item.value %> | <%= item.service %> |
<% end -%>
<% end %>

Data grabbed at: <%= local_time %>
END

    data = grab_today
    entry = erb(template, data)

    @log.info("Logging Exist data")
    tags = config['tags'] || ''
    today = @timespan
    DayOne.new.to_dayone({ 'content' => entry })

  end

  def auth_url
    "https://exist.io/oauth2/authorize?response_type=code&client_id=#{@exist_config['client_id']}&redirect_uri=#{@exist_config['redirect_uri']}&scope=read"
  end

  def token_url
    "https://exist.io/oauth2/access_token"
  end

  def user_auth
    # Start by asking the user to authorise the client. 
    print "Please copy the code from your web browser, and then paste it below:\n>>";
    %x{open "#{auth_url}"}

    # Now get the code from the user.
    code = gets.strip

    # Check it looks reasonable
    if code and code =~ /[0-9a-f]+/
      puts "\nThanks!"
    else
      puts "\nInvalid code"
      exit
    end

    # And exchange it for a token
    response = RestClient.post(
      token_url, 
      { 
        'grant_type'    => 'authorization_code',
        'code'          => code,
        'client_id'     => @exist_config['client_id'],
        'client_secret' => @exist_config['client_secret'],
        'redirect_uri'  => @exist_config['redirect_uri'],
      }
    )

    # Return the interesting bits
    data = JSON.parse(response.to_str)
    config['access_token'] = data['access_token']
    config['expires']      = Time.now + data['expires_in']

    config
  end

  def grab_today
    begin
      today = RestClient::Request.execute(
        method: :get,
        url: 'https://exist.io/api/1/users/$self/today/',
        headers: {'Authorization' => "Bearer #{@exist_config['access_token']}" }
      )

      puts today
    rescue => e
      puts e.response
    end

    JSON.parse(today, object_class: OpenStruct)
  end


  def erb(template, vars)
    ERB.new(template, nil, '-').result(vars.instance_eval { binding })
  end
end
