#!/usr/bin/env ruby

require 'date'
require 'csv'
require 'json'
require 'countries'
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

root = ARGV[0] || ENV.fetch('COVID19_PATH', nil) || File.join('..', 'COVID-19')
path = File.join(root, 'csse_covid_19_data', 'csse_covid_19_time_series')
raise "No such directory: #{path}" unless Dir.exist?(path)

world =
  {
    regions: Hash.new { |h, k| h[k] = {
      subregions: Hash.new { |h, k| h[k] = {
        countries: Hash.new { |h, k| h[k] = {
          states: Hash.new { |h, k| h[k] = {
            cities: {}
          }}
        }}
      }}
    }}
  }

['Confirmed', 'Recovered', 'Deaths'].each do |status|
  name = "time_series_19-covid-#{status}.csv"
  data = CSV.read(File.join(path, name), headers: true)
  data.each do |row|
    region = row['Country/Region']
    region = COUNTRY_MAP[region] if COUNTRY_MAP.has_key?(region)
    country = ISO3166::Country.find_country_by_name(region)
    if country.nil?
      puts "Skipping: #{row}" 
      next
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
    world[:regions][country.region] ||= {
      id: REGION_MAP[country.region],
      name: country.region
    }
    region = world[:regions][country.region]
    region[:subregions][country.subregion] ||= {
      id: SUBREGION_MAP[country.subregion],
      name: country.subregion
    }
    subregion = region[:subregions][country.subregion]
    subregion[:countries][country.name] ||= {
      id: country.alpha2,
      name: country.name,
      flag: country.emoji_flag
    }
    country = subregion[:countries][country.name]
    unless state_id.nil?
      country[:states][province] ||= {
        id: state_id,
        name: province
      }
      state = country[:states][province]
      unless city_name.nil?
        state[:cities][city_name] ||= {
          id: nil,
          name: city_name
        }
        city = state[:cities][city_name]
      end
    end
  end
end

debugger

puts "done"
