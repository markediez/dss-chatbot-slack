#!/usr/bin/env ruby

# DSS ChatBot
# Version 0.62 2016-06-02
# Written by Christopher Thielen <cmthielen@ucdavis.edu>

require 'rubygems'
require 'bundler/setup'
require 'daemons'
require 'logger'
require 'yaml'
require 'cgi'
require 'slack-ruby-client'

load './chat_bot_command.rb'

# Store the current working directory as Daemons.run_proc() will change it
$cwd = Dir.getwd

# Returns nil if file is not found or global settings is not set up
# @param path - file path
def load_settings(path)
  if File.file?(path)
    settings = YAML.load_file(path)

    if settings["GLOBAL"] == nil
      $stderr.puts "Settings file found but missing GLOBAL section. Cannot proceed."
      $logger.error "DSS ChatBot could not start because #{path} does not have a GLOBAL section. See config/settings.example.yml."
      return nil
    end

    $logger.info "Settings loaded."
  else
    $stderr.puts "You need to set up #{path} before running this script."
    $logger.error "DSS ChatBot could not start because #{path} does not exist. See config/settings.example.yml."
    return nil
  end

  return settings
end

# 'Daemonize' the process (see 'daemons' gem for more information)
Daemons.run_proc('dss-chatbot.rb') do
  # Log errors / information to console
  $logger = logger = Logger.new(STDOUT)

  # Keep a log file (auto-rotate at 1 MB, keep 10 rotations) of users using chatbot
  ROTATIONS = 10
  LOG_SIZE = 1024000
  $customer_log = Logger.new($cwd + "/chatbot-customers.log", ROTATIONS, LOG_SIZE)

  logger.info "DSS ChatBot started at #{Time.now}"

  # Load sensitive settings from config/*
  $settings_file = $cwd + '/config/settings.yml'
  $SETTINGS = load_settings($settings_file)
  exit if $SETTINGS == nil

  # Set up chat commands plugin
  ChatBotCommand.initialize($cwd)

  # Set up Slack connection
  Slack.configure do |config|
    config.token = $SETTINGS['SLACK_API_TOKEN']
  end

  client = Slack::RealTime::Client.new
  client.on :hello do
    logger.info "Successfully connected, welcome '#{client.self['name']}' to the '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com."
  end

  client.on :close do
    logger.info "Caught close signal. Attempting to restart ..."
    EM.stop
  end

  client.on :message do |data|
    # Check if the message was sent by this chat bot ... we don't need to
    # talk to ourselves.
    self_id = client.self["id"]
    next if data["user"] == self_id

    # True if the channel is one of the channels directly messaging chatbot
    is_dm = client.ims[data["channel"]] != nil
    # Parse the received message for valid Chat Bot commands
    if data['text']
      response = ChatBotCommand.dispatch(data['text'], data['channel'], client.users[data["user"]], is_dm)
      client.message(channel: data['channel'], text: response) unless response == nil
    end
  end

  client.on :group_joined do
    $logger.info "Entered private channel, reloading data"
    ChatBotCommand.reload_channels!
  end

  # Loop itself credit slack-ruby-bot: https://github.com/dblock/slack-ruby-bot/blob/798d1305da8569381a6cd70b181733ce405e44ce/lib/slack-ruby-bot/app.rb#L45
  loop do
    logger.info "Marking the start of the client loop!"
    begin
      client.start!
    rescue Slack::Web::Api::Error => e
      logger.error e
      case e.message
      when 'migration_in_progress'
        sleep 5 # ignore, try again
      else
        raise e
      end
    rescue Faraday::Error::TimeoutError, Faraday::Error::ConnectionFailed, Faraday::Error::SSLError, Faraday::ClientError => e
      logger.error e
      sleep 5 # ignore, try again
    rescue StandardError => e
      logger.error e
      raise e
    # ensure
      # client = nil
    end
  end

  logger.info "DSS ChatBot ended at #{Time.now}"
end
