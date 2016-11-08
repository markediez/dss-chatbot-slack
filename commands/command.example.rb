# module ChatBotCommand
#   class CommandName
#     TITLE = "Visioneer"        # Title of the command
#     REGEX = /^visioneers/      # REGEX the command needs to look for
#     COMMAND = "visioneers"     # Command to use
#     DESCRIPTION = "TODO"       # Description of the command
#
#     # Run MUST return a string
#     # @param message - message posted
#     # @param channel - the channel where the message was posted
#     # @param can_view_private - flag if extra data can be outputted
#     def run(message, channel, can_view_private)
#       if Time.now.hour < 17
#         return "There are #{((Time.new(Time.now.year, Time.now.month, Time.now.day, 17, 0, 0) - Time.now) / 60).to_i} minutes of productivity remaining in the day."
#       else
#         return "There are no minutes of productivity remaining in the day."
#       end
#     end
#
#     # Essential to make commands a singleton
#     @@instance = Visioneers.new
#     def self.get_instance
#       return @@instance
#     end
#
#     # Avoids any "accidental" call to new outside of the class
#     private_class_method :new
#   end
# end
