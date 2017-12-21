#! /usr/bin/env ruby
#
#   metrics-tomcat-jmxproxy
#
# DESCRIPTION:
#   Return value of JMX attribute to Graphite via Tomcat's JMXProxy
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
#    ./metrics-tomcat-jmxproxy.rb --url http://localhost:8080 --account admin --password password --bean 'java.lang:type=MemoryPool,name=Compressed Class Space' --attribute PeakUsage --key used --scheme my.scheme
#
#    my.scheme.PeakUsage.used 2523848 1513887865
#
#
# NOTES:
#
# See http://localhost:8080/docs/manager-howto.html for security information

require 'sensu-plugin/metric/cli'
require 'unirest'
require 'uri'

class MetricsTomcatJMXProxy < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         description: 'URL of the Tomcat Manager',
         short: '-u URL',
         long: '--url URL',
         default: 'http://localhost:8080',
         required: true

  option :account,
         description: 'Username of the Tomcat User that has the manager-jmx role',
         short: '-a USERNAME',
         long: '--account USERNAME',
         default: 'admin',
         required: true

  option :password,
         description: 'Tomcat User password',
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         default: 'password',
         required: true

  option :bean,
         description: 'Full name of the MBean to query',
         short: '-b VALUE',
         long: '--bean VALUE',
         default: 'java.lang:type=Memory',
         required: true

  option :attribute,
         description: 'MBean attribute to return. Default metric name',
         short: '-l VALUE',
         long: '--attribute VALUE',
         default: 'HeapMemoryUsage',
         required: true

  option :attrkey,
         description: 'Key of a CompositeData MBean attribute. Optional',
         short: '-k VALUE',
         long: '--key VALUE',
         required: false

  option :scheme,
         description: 'Metric naming scheme. Defaults to hostname',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: Socket.gethostname.to_s

  option :metric,
         description: 'Override attribute name metric',
         short: '-M METRIC',
         long: '--metric METRIC',
         required: false

  def run
    uri = URI("#{config[:url]}/manager/jmxproxy?get=#{config[:bean]}&att=#{config[:attribute]}")
    fq_metric = config[:scheme] + '.' + (config[:metric] || config[:attribute])

    if config[:attrkey]
      uri.query += "&key=#{config[:attrkey]}"
      fq_metric += '.' + config[:attrkey].to_s
    end

    # Fetch attribute from Tomcat
    Unirest.timeout(5) # 5s timeout
    response = Unirest.get uri.to_s, auth: { user: @config[:account].to_s, password: @config[:password].to_s }

    if response.code != 200
      critical "Failed to obtain response from Tomcat\n"\
      "HTTP Response Code: #{response.code}\n"\
      "URL: #{uri}\n"
    else
      # Supported formats:
      # OK - Attribute get 'java.lang:type=Memory' - Verbose = false
      # OK - Attribute get 'java.lang:type=Memory' - HeapMemoryUsage - key 'used' = 1234
      # Error - Error message here\nstacktrace\nstacktrace\n...
      #
      # FIXME support CompositeData
      # OK - Attribute get 'java.lang:type=Memory' - HeapMemoryUsage = javax.management.openmbean.CompositeDataSupport(...)

      fields = response.raw_body.split(' - ')

      if fields[0] != 'OK'
        trunc_error = fields[1].split("\n")
        critical "#{fields[0]} #{trunc_error[0].chomp}"
      end

      output(fq_metric, fields[-1].split(' = ', 2)[1].chomp)
      ok
    end
  rescue Errno::ECONNREFUSED
    critical "Could not connect to Tomcat on #{config[:url]}"
  end
end
