#!/usr/bin/env ruby

require 'date'
require 'csv'
require 'json'
require 'byebug'

root = ARGV[0] || ENV.fetch('COVID19_PATH', nil) || File.join('..', 'COVID-19')
path = File.join(root, 'csse_covid_19_data', 'csse_covid_19_daily_reports')
raise "No such directory: #{path}" unless Dir.exist?(path)

province_map = {}
region_map = {}
Dir.children(path).each do |name|
  next unless File.extname(name) == '.csv'
  data = CSV.read(File.join(path, name), headers: true)
  name = Date.strptime(name, "%m-%d-%Y.csv").strftime
  data.each do |row|
    province = row['Province/State']&.strip || "N/A"
    province_map[province] ||= "TBD"
    region = row['Country/Region']&.strip || "N/A"
    region_map[region] ||= "TBD"
  end
end
File.write('province_map.json', JSON.pretty_generate(province_map))
File.write('region_map.json', JSON.pretty_generate(region_map))
