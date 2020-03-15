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
  state_id = nil
  city_name = nil
  unless province.nil?
    city_name, state_id = province.split(',').map(&:strip)
    if state_id.nil?
      city_name = nil
      state_map = Hash[country.states.map { |key, value| [value.name, key] }]
      state_id = state_map[province]
    else
      state_id = "DC" if state_id == "D.C."
      province = country.states[state_id].name
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
  # TODO: break this down into a series
  row
end

def city_acronyms(data)
  data.each do |key, value|
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
    next if value.length.zero?
    next unless value.is_a?(Hash)
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

root = ARGV[0] || ENV.fetch('COVID19_PATH', nil) || File.join('..', 'COVID-19')
path = File.join(root, 'csse_covid_19_data', 'csse_covid_19_time_series')
raise "No such directory: #{path}" unless Dir.exist?(path)

world = {}
['Confirmed', 'Recovered', 'Deaths'].each do |status|
  name = "time_series_19-covid-#{status}.csv"
  data = CSV.read(File.join(path, name), headers: true)
  data.each do |row|
    next unless node = add_row(world, row)
    node[:series] ||= {}
    process_series(node[:series], status.downcase.to_sym, data.headers, row)
  end
end
File.write('world.json', JSON.pretty_generate(world))

{
  confirmed: {
    total: 0,
    delta: 0,
    growth: 0
  },
  deaths: {
    total: 0,
    delta: 0,
    growth: 0,
    ratio: 0
  },
  recovered: {
    total: 0,
    delta: 0,
    growth: 0,
    ratio: 0
  }
}

city_acronyms(world)
world = regenerate_keys(world)
debugger
# TODO: iterate to update keys to be IDs instead of names
# TODO: iterate to create a series at all nodes that don't have one
# TODO: generate directory of json data, including one date for "latest"
# TODO: update to AWS, put on the interwebs and announce to the world

# TODO: add metadata (total, delta, growth, frequency, deaths/new cases)

# TODO: generate PNG badges for trend (node) and summary (children)

puts "done"
