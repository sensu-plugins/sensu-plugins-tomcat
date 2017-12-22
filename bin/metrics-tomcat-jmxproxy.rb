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
#   gem: addressable
#   gem: sensu-plugin
#   gem: unirest
#
# USAGE:
#  Basic Usage:
#    ./metrics-tomcat-jmxproxy.rb
#      --url http://localhost:8080
#      --account admin
#      --password password
#      --bean 'java.lang:type=MemoryPool,name=Compressed Class Space'
#      --attribute PeakUsage
#      --key used
#      --scheme my.scheme
#
#    my.scheme.PeakUsage.used 2523848 1513887865
#
# NOTES:
#
# See http://localhost:8080/docs/manager-howto.html for security information

require 'addressable/uri'
require 'sensu-plugin/metric/cli'
require 'unirest'

class MetricsTomcatJMXProxy < Sensu::Plugin::Metric::CLI::Graphite
  option :url,
         description: 'URL of the Tomcat Manager',
         short: '-u URL',
         long: '--url URL',
         required: true

  option :account,
         description: 'Username of the Tomcat User that has the manager-jmx role',
         short: '-a USERNAME',
         long: '--account USERNAME',
         required: true

  option :password,
         description: 'Tomcat User password',
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         required: true

  option :bean,
         description: 'Full name of the MBean to query',
         short: '-b VALUE',
         long: '--bean VALUE',
         required: true

  option :attribute,
         description: 'MBean attribute to return. Default metric name',
         short: '-l VALUE',
         long: '--attribute VALUE',
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

  option :timeout,
         description: 'HTTP request timeout in seconds. Default: 5',
         short: '-T TIMEOUT',
         long: '--timeout TIMEOUT',
         default: 5,
         required: false

  def run
    uri = Addressable::URI.parse("#{config[:url]}/manager/jmxproxy?get=#{config[:bean]}&att=#{config[:attribute]}")
    fq_metric = config[:scheme] + '.' + (config[:metric] || config[:attribute])

    if config[:attrkey]
      uri.query += "&key=#{config[:attrkey]}"
      fq_metric += '.' + config[:attrkey].to_s
    end

    uri.normalize!
    fq_metric.downcase!

    # Fetch attribute from Tomcat
    Unirest.timeout(config[:timeout])
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
