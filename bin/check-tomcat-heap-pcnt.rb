#! /usr/bin/env ruby
#
#   check-tomcat-heap-pcnt
#
# DESCRIPTION: Check the percentage of JVM Memory:
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
#   gem: crack
#
# USAGE:
#  Basic Usage:
#    ./check-tomcat-heap-pcnt
#  Specify Thresholds:
#    ./check-tomcat-heap-pcnt -w 80 -c 90
#
# NOTES:
#
# See http://localhost:8080/docs/manager-howto.html for security information

require 'sensu-plugin/check/cli'
require 'unirest'
require 'crack'

class CheckTomcatHeapMemory < Sensu::Plugin::Check::CLI
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
         required: true

  option :warn,
         description: 'The percentage of HEAP memory used',
         short: '-w VALUE',
         long: '--warning VALUE',
         default: '80',
         required: true

  option :crit,
         description: 'The percentage of HEAP memory used',
         short: '-c VALUE',
         long: '--critical VALUE',
         default: '90',
         required: true

  def run
    # Fetch XML Status from Tomcat Manager
    Unirest.timeout(5) # 5s timeout
    response = Unirest.get "#{config[:url]}/manager/status/all?XML=true", auth: { user: @config[:account].to_s, password: @config[:password].to_s }

    if response.code != 200
      unknown "Failed to obtain response from Tomcat\n"\
      "HTTP Response Code: #{response.code}\n"\
      "URL: #{config[:url]}/status/all?XML=true\n"
    else
      # Convert XML to Ruby Hash
      response_hash = Crack::XML.parse(response.body)

      # Set Vars based on Hash elements
      max = response_hash['status']['jvm']['memory']['max'].to_f
      total = response_hash['status']['jvm']['memory']['total'].to_f
      free = response_hash['status']['jvm']['memory']['free'].to_f
      pct_used = ((total - free) / max * 100).to_i

      if pct_used > config[:crit].to_i
        critical "Java HEAP Memory Usage #{pct_used}%"
      elsif pct_used > config[:warn].to_i
        warning "Java HEAP Memory Usage #{pct_used}%"
      else
        ok "Java HEAP Memory Usage #{pct_used}%"
      end
    end
  end
end
