#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems' unless defined? Gem # rubygems is only needed in 1.8
require "bundle/bundler/setup"
require "alfred"
require 'fog'

AWS_ACCESS_KEY = "AKIAIPLUUKDZOY4PCEFQ"
AWS_SECRET_KEY = "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"

Alfred.with_friendly_error do |alfred|
  fb         = alfred.feedback
  connection = Fog::Compute.new({
                                    :provider              => 'AWS',
                                    :aws_access_key_id     => AWS_ACCESS_KEY,
                                    :aws_secret_access_key => AWS_SECRET_KEY
                                })

  cloudwatch = Fog::AWS::CloudWatch.new(:aws_access_key_id => AWS_ACCESS_KEY, :aws_secret_access_key => AWS_SECRET_KEY)

  servers = connection.servers.sort_by { |server| server.id }

  #puts servers.inspect

  servers.each do |server|
    output = case server.state
               when 'running'
                 result   = cloudwatch.get_metric_statistics({ 'MetricName' => "CPUUtilization",
                                                               "Statistics" => ["Average"],
                                                               'StartTime'  => (Time.now.utc-(10*60)).iso8601,
                                                               'EndTime'    => Time.now.utc.iso8601,
                                                               'Period'     => 300,
                                                               'Namespace'  => 'AWS/EC2',
                                                               'Dimensions' => [{ "Name" => "InstanceId", "Value" => server.id }] })
                 #puts result.inspect
                 cpu_data = result.body["GetMetricStatisticsResult"]["Datapoints"]
                 cpu      = cpu_data ? "#{cpu_data.first["Average"]}%" : "Unknown"

                 "#{server.id} (#{server.state} cpu: #{cpu})"
               else
                 "#{server.id} (#{[server.state].join(' ')})"
             end
    fb.add_item(:title => server.tags['Name'], :subtitle => output)
  end
  puts fb.to_xml(ARGV)
end



