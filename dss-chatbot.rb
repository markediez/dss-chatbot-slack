# DSS ChatBot
# Version 0.3 2015-09-04
# Written by Christopher Thielen <cmthielen@ucdavis.edu>

require 'rubygems'
require 'bundler/setup'

require 'daemons'
require 'sysaid'
require 'logger'
require 'cgi'
require 'ldap'
require 'slack-ruby-client'

SETTINGS_FILE = "config/settings.yml"
LDAP_MAX_RESULTS = 8

# Keep a log file (auto-rotate at 1 MB, keep 10 rotations)
logger = Logger.new('dss-chatbot.log', 10, 1024000)

logger.info "DSS ChatBot started at #{Time.now}"

# Load sensitive settings from config/*
if File.file?(SETTINGS_FILE)
  $SETTINGS = YAML.load_file(SETTINGS_FILE)
  logger.info "Settings loaded."
else
  $stderr.puts "You need to set up #{SETTINGS_FILE} before running this script."
  logger.error "DSS ChatBot could not start because #{SETTINGS_FILE} does not exist. See config/settings.example.yml."
  exit
end

# Set up Slack connection
Slack.configure do |config|
  config.token = $SETTINGS['SLACK_API_TOKEN']
end

# Log into SysAid
begin
  SysAid::login $SETTINGS['SYSAID_ACCOUNT'], $SETTINGS['SYSAID_USER'], $SETTINGS['SYSAID_PASSWORD'], $SETTINGS['SYSAID_URI']
  logger.info "Logged into SysAid."
rescue Exception => e
  $stderr.puts "Failed to connect to SysAid: #{e}"
  logger.error "DSS ChatBot could not start because it failed to connect to SysAid. Exception: #{e}"
  exit
end

#         case command
#         when 'ldap'
#           reply_message = ldap_command(message)
#         when 'visioneers'

def sysaid_command(message)
  ticket_id = message[/\d+/] # ticket ID of the message

  return "" unless ticket_id

  link = "https://sysaid.dss.ucdavis.edu/index.jsp#/SREdit.jsp?QuickAcess&id=" + ticket_id # link template for a SysAid ticket given ID

  # Find ticket in SysAid
  ticket = SysAid::Ticket.find_by_id(ticket_id)
  if ticket.nil?
    # Ticket does not exist.
    return "Couldn't find a ticket with ID #{ticket_id}"
  else
    # Ticket exists, compose 'reply_message'
    return "*#{ticket.title}* requested by *#{ticket.request_user}*: #{link}"
  end
end

def ldap_command(message)
  term = message[5..-1]

  # Connect to LDAP
  conn = LDAP::SSLConn.new( $SETTINGS['LDAP_HOST'], $SETTINGS['LDAP_PORT'].to_i )
  conn.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
  conn.bind(dn = $SETTINGS['LDAP_BASE_DN'], password = $SETTINGS['LDAP_BASE_PW'] )

  search_terms = "(|(uid=#{term})(mail=#{term})(givenName=#{term})(sn=#{term})(cn=#{term}))"
  results = ""
  result_count = 0;

  conn.search($SETTINGS['LDAP_SEARCH_DN'], LDAP::LDAP_SCOPE_SUBTREE, search_terms) do |entry|
    if result_count > 0
      results += "\n"
    end

    result_count = result_count + 1

    unless entry.get_values('displayName').to_s[2..-3].nil?
      name = entry.get_values('displayName').to_s[2..-3]
    else
      name = "Not listed"
    end
    unless entry.get_values('uid').to_s[2..-3].nil?
      loginid = entry.get_values('uid').to_s[2..-3]
    else
      loginid = "Not listed"
    end
    unless entry.get_values('mail').to_s[2..-3].nil?
      mail = entry.get_values('mail').to_s[2..-3]
    else
      mail = "Not listed"
    end
    unless entry.get_values('street').to_s[2..-3].nil?
      office = entry.get_values('street').to_s[2..-3]
    else
      office = "Not listed"
    end
    unless entry.get_values('ou').to_s[2..-3].nil?
      department = entry.get_values('ou').to_s[2..-3]
    else
      department = "Not listed"
    end

    affiliations = []
    # A person may have multiple affiliations
    entry.get_values('ucdPersonAffiliation').each do |affiliation_name|
      affiliations << affiliation_name
    end
    if affiliations.length == 0
      affiliations = "Not listed"
    else
      affiliations = affiliations.join(", ")
    end

    results += "*Name* #{name}\n"
    results += "*Login ID* #{loginid}\n"
    results += "*E-Mail* #{mail}\n"
    results += "*Department* #{department}\n"
    results += "*Office* #{office}\n"
    results += "*Affiliation* #{affiliations}\n"
  end

  conn.unbind

  if result_count > LDAP_MAX_RESULTS
    return "Too many results (#{result_count}). Try narrowing your search."
  elsif result_count == 0
    return "No results found."
  else
    return results
  end
end

def visioneers_command
  if(Time.now.hour < 17)
    return "There are #{((Time.new(Time.now.year, Time.now.month, Time.now.day, 17, 0, 0) - Time.now) / 60).to_i} minutes of productivity remaining in the day."
  else
    return "There are no minutes of productivity remaining in the day."
  end
end

client = Slack::RealTime::Client.new

client.on :hello do
  logger.info "Successfully connected, welcome '#{client.self['name']}' to the '#{client.team['name']}' team at https://#{client.team['domain']}.slack.com."
end

client.on :message do |data|
  case data['text']
  when /sysaid/i then
    client.message channel: data['channel'], text: sysaid_command(data['text'])
  when /#[0-9]+/ then
    client.message channel: data['channel'], text: sysaid_command(data['text'])
  when /^ldap/ then
    client.message channel: data['channel'], text: ldap_command(data['text'])
  when /^visioneers/ then
    client.message channel: data['channel'], text: visioneers_command
  end
end

client.start!
