#! /usr/bin/env ruby
#
#   check-tomcat-app-deployment
#
# DESCRIPTION: Check current runtime status/deploymnet status of a application:
#   A deployment represents anything that can be deployed:
#   Such as EJB-JAR, WAR, EAR, any kind of standard archive such as RAR or Tomcat-specific deployment)
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: unirest
#
# USAGE:
#  Basic Usage:
#    ./check-tomcat-app-deployment
#  Specify Applications:
#    check-tomcat-app-deployment -l '/manager,/jasperreports'
#
# NOTES:
#
# See http://localhost:8080/docs/manager-howto.html for security information

require 'sensu-plugin/check/cli'
require 'unirest'

class CheckTomcatAppDeployment < Sensu::Plugin::Check::CLI
  option :url,
         description: 'URL of the Tomcat Manager',
         short: '-u URL',
         long: '--url URL',
         default: 'http://localhost:8080',
         required: true

  option :account,
         description: 'Username of the Tomcat User, that has the manager-script role',
         short: '-a USERNAME',
         long: '--account USERNAME',
         default: 'admin',
         required: true

  option :password,
         description: 'Tomcat User password',
         short: '-p PASSWORD',
         long: '--passowrd PASSWORD',
         default: 'password',
         require: true

  option :apps,
         description: 'A comma seperated list of application paths to verify are in a running state',
         short: '-l VALUE',
         long: '--applications VALUE',
         default: '/,/manager',
         required: true

  def run
    # Fetch XML Status from Tomcat Manager
    Unirest.timeout(5) # 5s timeout
    response = Unirest.get "#{config[:url]}/manager/text/list", auth: { user: @config[:account].to_s, password: @config[:password].to_s }

    if response.code != 200
      unknown "Failed to obtain response from Tomcat\n"\
      "HTTP Response Code: #{response.code}\n"\
      "URL: #{config[:url]}/status/all?XML=true\n"
    else
      # Create a array based on newlines
      response = response.body.split("\n")

      # Create a hash bashed on the above array
      response_hash = Hash[response.map { |it| it.split(':', 2) }]

      # Empty Array for app status
      app_with_errors ||= []

      # Create Array from :apps option
      apps = config[:apps].split(',')

      apps.each do |app|
        if response_hash[app]
          unless response_hash[app].include?('running')
            # Add apps that are not in a running state
            app_with_errors << app
          end
        else
          # Add apps that are not installed
          app_with_errors << app
        end
      end

      if app_with_errors.any?
        critical "The applications #{app_with_errors} are NOT in a running state"
      else
        ok "The applications #{apps} are in a running state"
      end

    end
  end
end
