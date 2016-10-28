require "net/http"

module ChatBotCommand
  class Email
    TITLE = "Email"
    REGEX = /^!email\s+/
    COMMAND = "!email @user_name or !email username or !email name"
    DESCRIPTION = "Output the email address of the user"

    @users = Hash.new

    def run(message, channel)
      # Generate a hash for querying
      generate_users_hash()

      queried_users = []
      case message
      when /^!email\s+(<\S+>)\s*$/ # query by @user
        # at this point, user is "<@SOMEID>"
        user = /^!email\s+(<\S+>)\s*$/.match(message)[1]

        # we only need SOMEID
        user = user[2...user.index(">")]
        queried_users.push(user)
      else /(\S+)/ # query by "msdiez" / "Mark Diez"
        # shift to remove !email
        query = message.scan(/(\S+)/)
        query.shift
        user = ""
        query.each do |item|
          user = user + item[0] + " "
        end

        # remove ending whitespace
        user.strip!

        # get possible users
        possible_users = @users.keys.grep(/#{user}/)
        queried_users.push(*possible_users)
      end

      response = ""
      queried_users.each do |user|
        response += ">" + user + ": " +  @users[user] + "\n"
      end

      return response.empty? ? "User does not exist" : response
    end # def run

    # Returns a hash of :user => email of all users in the team else a string
    def generate_users_hash
      @users = Hash.new
      # Get a list of user data from slack api
      uri = URI.parse("https://slack.com/api/users.list")
      args = {token: $SETTINGS["SLACK_API_TOKEN"]}
      uri.query = URI.encode_www_form(args)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.code == "200"
        result = JSON.parse(response.body)
        users = result["members"]
        users.each do |user|
          username = user["name"]
          user_id = user["id"]
          user_full_name = user["real_name"]
          user_email = user["profile"]["email"]

          @users[user_id] = user_email
          @users[username] = user_email
          @users[user_full_name] = user_email
        end
      else
        $logger.error "Could not connect to Slack API due to #{response.code}"
        return "Could not connect to Slack API due to #{response.code}"
      end
    end # def generate_user_array

    def self.get_instance
      @@instance ||= Email.new
    end

    private_class_method :new
  end # class Email
end # module ChatBotCommand
