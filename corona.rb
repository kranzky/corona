#!/usr/bin/env ruby

require 'date'
require 'csv'
require 'json'
require 'countries'
require 'acronym'
require 'fileutils'
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
  unless data[:series].nil? || series.nil?
    data[:series].each do |key, value|
      [:confirmed, :deaths, :recovered].each do |status|
        next unless value[status][:total].zero?
        value[status][:total] = series[key][status][:total]
      end
    end
  end
  data[:series] ||= series
end

def generate_metadata(data)
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    next if key == :series
    generate_metadata(value)
  end
  return if data[:series].nil?
  prev = {
    confirmed: [0,0,0,0],
    deaths: [0,0,0,0],
    recovered: [0,0,0,0]
  }
  data[:series].each do |key, value|
    [:confirmed, :deaths, :recovered].each do |status|
      total = value[status][:total]
      prev_delta = prev[status][2] - prev[status][0]
      this_delta = total - prev[status][2]
      value[status][:growth] = this_delta.to_f / prev_delta.to_f if prev_delta != 0
      value[status][:delta] = total - prev[status].last
      prev[status] << total
      prev[status].shift
    end
  end
end

def write_file(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  data[:source] = {
    uri: "https://github.com/CSSEGISandData/COVID-19"
  }
  data[:home] = {
    uri: "https://github.com/kranzky/corona"
  }
  File.write(path, JSON.pretty_generate(data))
end

def write_state(state, root, prefix)
  index = {
    id: state[:id],
    name: state[:name],
    series: state[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
end

def write_country(country, root, prefix)
  states = {}
  country[:states].each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    write_state(value, File.join(root, id), uri)
    states[id] = {
      id: key,
      name: value[:name],
      uri: "#{uri}.json"
    }
  end
  index = {
    id: country[:id],
    name: country[:name],
    flag: country[:flag],
    states: states,
    series: country[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
end

def write_subregion(subregion, root, prefix)
  countries = {}
  subregion[:countries].each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    write_country(value, File.join(root, id), uri)
    countries[id] = {
      id: key,
      name: value[:name],
      flag: value[:flag],
      uri: "#{uri}.json"
    }
  end
  index = {
    id: subregion[:id],
    name: subregion[:name],
    countries: countries,
    series: subregion[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
end

def write_region(region, root, prefix)
  subregions = {}
  region[:subregions].each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    write_subregion(value, File.join(root, id), uri)
    subregions[id] = {
      id: key,
      name: value[:name],
      uri: "#{uri}.json"
    }
  end
  index = {
    id: region[:id],
    name: region[:name],
    subregions: subregions,
    series: region[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
end

def write_world(world, root, prefix)
  regions = {}
  world.each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    write_region(value, File.join(root, id), uri)
    regions[id] = {
      name: value[:name],
      uri: "#{uri}.json"
    }
  end
  index = {
    name: 'Earth',
    regions: regions,
    series: world[:series]
  }
  write_file(File.join(root, 'index.json'), index)
end

def generate_badges(world)
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
generate_metadata(world)
show_world(world)
write_world(world, 'www', 'https://corona.kranzky.com')
generate_badges(world)
