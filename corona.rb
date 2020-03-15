#!/usr/bin/env ruby

require 'date'
require 'csv'
require 'json'
require 'countries'
require 'acronym'
require 'byebug'

COUNTRY_MAP = {
  'US' => 'United States',
  'Taiwan*' => 'Taiwan',
  'Congo (Kinshasa)' => 'Congo'
}

REGION_MAP = {
  'Africa' => 'AF',
  'Americas' => 'AM',
  'Asia' => 'AS',
  'Europe' => 'EU',
  'Oceania' => 'OC'
}

SUBREGION_MAP = {
  'Australia and New Zealand' => 'ANZ',
  'Caribbean' => 'CAR',
  'Central America' => 'CAM',
  'Central Asia' => 'CA',
  'Eastern Africa' => 'EAF',
  'Eastern Asia' => 'EA',
  'Eastern Europe' => 'CEE',
  'Middle Africa' => 'MAF',
  'Northern Africa' => 'NAF',
  'Northern America' => 'NA',
  'Northern Europe' => 'NEU',
  'South America' => 'SAM',
  'South-Eastern Asia' => 'SEA',
  'Southern Africa' => 'SAF',
  'Southern Asia' => 'SA',
  'Southern Europe' => 'SEU',
  'Western Africa' => 'WAF',
  'Western Asia' => 'WA',
  'Western Europe' => 'WEU'
}

def add_row(world, row)
  region = row['Country/Region']
  region = COUNTRY_MAP[region] if COUNTRY_MAP.has_key?(region)
  country = ISO3166::Country.find_country_by_name(region)
  if country.nil?
    puts "Skipping: #{row}" 
    return
  end
  province = row['Province/State']
  return nil if province =~ /Princess/
  state_id = nil
  city_name = nil
  unless province.nil?
    city_name, state_id = province.split(',').map(&:strip)
    if state_id.nil?
      city_name = nil
      state_map = Hash[country.states.map { |key, value| [value.name, key] }]
      state_id = state_map[province] || province
    else
      state_id = "DC" if state_id == "D.C."
      state_id = 'VI' if state_id == "U.S." && city_name == 'Virgin Islands'
      province = country.states[state_id].name
    end
    if country.name == 'China'
      state_id = province
    end
  end
  world[country.region] ||= {
    id: REGION_MAP[country.region],
    name: country.region,
    subregions: {}
  }
  region = world[country.region]
  region[:subregions][country.subregion] ||= {
    id: SUBREGION_MAP[country.subregion],
    name: country.subregion,
    countries: {}
  }
  subregion = region[:subregions][country.subregion]
  subregion[:countries][country.name] ||= {
    id: country.alpha2,
    name: country.name,
    flag: country.emoji_flag,
    states: {}
  }
  country = subregion[:countries][country.name]
  node = country
  unless state_id.nil?
    country[:states][province] ||= {
      id: state_id,
      name: province,
      cities: {}
    }
    state = country[:states][province]
    node = state
    unless city_name.nil?
      state[:cities][city_name] ||= {
        id: nil,
        name: city_name
      }
      city = state[:cities][city_name]
      node = city
    end
  end
  node
end

def process_series(series, status, headers, row)
  headers.each do |name|
    date = Date.strptime(name, '%m/%d/%y').strftime rescue nil
    next if date.nil?
    series[date] ||=
      {
        confirmed: {
          total: 0,
          delta: 0,
          growth: 0
        },
        deaths: {
          total: 0,
          delta: 0,
          growth: 0
        },
        recovered: {
          total: 0,
          delta: 0,
          growth: 0
        }
      }
    series[date][status][:total] = row[name].to_i
  end
end

def state_acronyms(data)
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    if key == :states
      ids = Acronym.new(value.values.map { |state| state[:name] }).to_a.map(&:upcase)
      value.values.each do |state|
        acronym = ids.shift
        state[:id] = acronym unless state[:id] =~ /^[A-Z][A-Z][A-Z]*$/
      end
    elsif value.is_a?(Hash)
      state_acronyms(value)
    end
  end
end

def city_acronyms(data)
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    if key == :cities
      ids = Acronym.new(value.values.map { |city| city[:name] }).to_a.map(&:upcase)
      value.values.each { |city| city[:id] = ids.shift }
    elsif value.is_a?(Hash)
      city_acronyms(value)
    end
  end
end

def regenerate_keys(data)
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    next if key == :series
    data[key] = regenerate_keys(value)
  end
  data.transform_keys do |key|
    if data[key].is_a?(Hash)
      data.dig(key, :id) || key
    else
      key
    end
  end
end

def merge_records(left, right)
  retval = Marshal.load(Marshal.dump(left))
  [:confirmed, :deaths, :recovered].each do |status|
    retval[status][:total] += right[status][:total]
  end
  retval
end

def merge_series(left, right)
  return right if left.nil?
  return left if right.nil?
  retval = {}
  left.keys.each do |key|
    next unless key =~ /2020/
    retval[key] = merge_records(left[key], right[key])
  end
  retval
end

def show_world(data, name='world', depth=0)
  name = data[:name] || name
  name = "#{name} (#{data[:id]})" unless data[:id].nil?
  total = nil
  total = data[:series]['2020-03-14'][:confirmed][:total] unless data[:series].nil?
  puts "#{' ' * (depth * 3)}#{name}: #{total}"
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    next if key == :series
    show_world(value, key, depth+1)
  end
end

def generate_series(data)
  series = nil
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    next if key == :series
    series = merge_series(series, generate_series(value))
  end
  data[:series] ||= series
end

def generate_metadata(data)
end

def write_files(world)
  # create a directory named www
  # write index.json
end

root = ARGV[0] || ENV.fetch('COVID19_PATH', nil) || File.join('..', 'COVID-19')
path = File.join(root, 'csse_covid_19_data', 'csse_covid_19_time_series')
raise "No such directory: #{path}" unless Dir.exist?(path)

world = {}
['Confirmed', 'Recovered', 'Deaths'].each do |status|
  puts status
  name = "time_series_19-covid-#{status}.csv"
  data = CSV.read(File.join(path, name), headers: true)
  total = 0
  data.each do |row|
    total += row[data.headers.last].to_i
    next unless node = add_row(world, row)
    node[:series] ||= {}
    process_series(node[:series], status.downcase.to_sym, data.headers, row)
  end
  puts total
end
state_acronyms(world)
city_acronyms(world)
world = regenerate_keys(world)
generate_series(world)
show_world(world)
generate_metadata(world)
write_files(world)
debugger
File.write('world.json', JSON.pretty_generate(world))
# TODO: generate PNG badges for trend (node) and summary (children)
