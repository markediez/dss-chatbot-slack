module SlackBotCommand
  class Visioneers
    REGEX = /^visioneers/
    COMMAND = "visioneers"
    DESCRIPTION = "TODO"
    
    def run(message)
      if(Time.now.hour < 17)
        return "There are #{((Time.new(Time.now.year, Time.now.month, Time.now.day, 17, 0, 0) - Time.now) / 60).to_i} minutes of productivity remaining in the day."
      else
        return "There are no minutes of productivity remaining in the day."
      end
    end
  end
end
