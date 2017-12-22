require_relative '../spec_helper.rb'
require_relative '../../bin/metrics-tomcat-jmxproxy.rb'

describe 'MetricsTomcatJMXProxy', '#run' do
  before(:all) do
    MetricsTomcatJMXProxy.class_variable_set(:@@autorun, nil)
  end

  it 'accepts config' do
    args = %w(--url http://127.0.0.1:8080 --account testacct --password test123 --bean foobean --attribute fooattr --key bar --scheme f.o.o --metric d -T 7)
    check = MetricsTomcatJMXProxy.new(args)
    expect(check.config[:url]).to eq 'http://127.0.0.1:8080'
    expect(check.config[:account]).to eq 'testacct'
    expect(check.config[:password]).to eq 'test123'
    expect(check.config[:bean]).to eq 'foobean'
    expect(check.config[:attribute]).to eq 'fooattr'
    expect(check.config[:attrkey]).to eq 'bar'
    expect(check.config[:scheme]).to eq 'f.o.o'
    expect(check.config[:metric]).to eq 'd'
    expect(check.config[:timeout]).to eq '7'
  end

  it 'connection refused handling' do
    args = %w(--url http://127.254.253.252:9123 --account testacct --password test123 --bean foobean --attribute fooattr)
    check = MetricsTomcatJMXProxy.new(args)
    expect(check).to receive(:critical).with('Could not connect to Tomcat on http://127.254.253.252:9123').and_raise(Errno::ECONNREFUSED)
    expect { check.run }.to raise_error(Errno::ECONNREFUSED)
  end
end
