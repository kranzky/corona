#!/usr/bin/env ruby

require 'date'
require 'csv'
require 'json'
require 'countries'
require 'acronym'
require 'fileutils'
require 'rest-client'
require 'byebug'

URL = DATA.read

COUNTRY_MAP = {
  'US' => 'United States',
  'Taiwan*' => 'Taiwan',
  'Republic of the Congo' => 'Congo',
  'occupied Palestinian territory' => 'Palestine, State of',
  'The Bahamas' => 'Bahamas',
  'The Gambia' => 'Gambia',
  'Bahamas, The' => 'Bahamas',
  'Gambia, The' => 'Gambia',
  'Burma' => 'Myanmar'
}

REGION_MAP = {
  'Africa' => 'AF',
  'Americas' => 'AM',
  'Asia' => 'AS',
  'Europe' => 'EU',
  'Oceania' => 'OC',
  'Special' => 'SP'
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
  'Western Europe' => 'WEU',
  "Nowhere" => "NOW"
}

FLAGS = [
  "🇨",
  "🇨",
  "🏴",
  "🇽",
  "🚩",
  "🏴",
  "🇵",
  "🏳️"
]

class FakeCountry
  @@count = 0
  attr_accessor :name
  def initialize(region)
    @name = region
    raise if @@count >= 8
    @@count += 1
    @count = @@count
  end
  def region
    "Special"
  end
  def subregion
    "Nowhere"
  end
  def states
    []
  end
  def alpha2
    '%02d' % @count
  end
  def emoji_flag
    FLAGS[@count-1]
  end
end

$fakes = {}

def add_row(world, row)
  region = row['Country/Region'] || row['Country_Region']
  region = COUNTRY_MAP[region] if COUNTRY_MAP.has_key?(region)
  country = ISO3166::Country.find_country_by_name(region)
  if country.nil?
    $fakes[region] ||= FakeCountry.new(region)
    country = $fakes[region]
  end
  province = row['Province/State'] || row['Province_State']
  return nil if province =~ /Princess/
  state_id = nil
  city_name = nil
  unless province.nil?
    city_name, state_id = province.split(',').map(&:strip)
    if state_id.nil?
      city_name = row['Admin2']
      state_map = Hash[country.states.map { |key, value| [value.name, key] }]
      state_id = state_map[province] || province
    else
      state_id = "DC" if state_id == "D.C."
      state_id = 'VI' if state_id == "U.S." && city_name == 'Virgin Islands'
      province =
        if country.states[state_id].nil?
          state_id
        else
          country.states[state_id].name
        end
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
  [:confirmed, :deaths].each do |status|
    retval[status][:total] += right[status][:total]
  end
  retval
end

def merge_series(left, right)
  return right if left.nil?
  return left if right.nil?
  retval = {}
  left.keys.each do |key|
    next unless key =~ /(2020|2021|2022|2023)/
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
      [:confirmed, :deaths].each do |status|
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
    confirmed: [0,0],
    deaths: [0,0]
  }
  data[:series].each do |key, value|
    [:confirmed, :deaths].each do |status|
      total = value[status][:total]
      prev_delta = prev[status][1] - prev[status][0]
      this_delta = total - prev[status][1]
      value[status][:growth] = this_delta.to_f / prev_delta.to_f if prev_delta != 0
      value[status][:growth] = 0 if value[status][:growth] <= 0
      value[status][:delta] = total - prev[status].last
      prev[status] << total
      prev[status].shift
    end
  end
end

def write_file(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  data[:source] = {
		attribution: "This is the data repository for the 2019 Novel Coronavirus Visual Dashboard operated by the Johns Hopkins University Center for Systems Science and Engineering (JHU CSSE). Also, Supported by ESRI Living Atlas Team and the Johns Hopkins University Applied Physics Lab (JHU APL).",
    uri: "https://github.com/CSSEGISandData/COVID-19",
		tos: "This GitHub repo and its contents herein, including all data, mapping, and analysis, copyright 2020 Johns Hopkins University, all rights reserved, is provided to the public strictly for educational and academic research purposes. The Website relies upon publicly available data from multiple sources, that do not always agree. The Johns Hopkins University hereby disclaims any and all representations and warranties with respect to the Website, including accuracy, fitness for use, and merchantability. Reliance on the Website for medical guidance or use of the Website in commerce is strictly prohibited."
  }
  data[:home] = {
    uri: "https://github.com/kranzky/corona",
		license: "http://unlicense.org"
  }
  blob = JSON.pretty_generate(data)
  if blob != (File.read(path) rescue "")
    puts "Writing #{path}"
    File.write(path, blob)
  end
end

def write_city(city, root, prefix)
  index = {
    id: city[:id],
    name: city[:name],
    badge: File.join(prefix, 'badge.svg'),
    series: city[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
end

def write_state(state, root, prefix)
  cities = {}
  state[:cities].each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    write_city(value, File.join(root, id), uri)
    cities[id] = {
      id: key,
      name: value[:name],
      uri: "#{uri}.json"
    }
    value[:series].values.last.each do |key, value|
      cities[id][key] = value[:total]
    end
  end
  index = {
    id: state[:id],
    name: state[:name],
    badge: File.join(prefix, 'badge.svg'),
    cities: Hash[cities.sort_by { |key, value| value[:name] }],
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
    value[:series].values.last.each do |key, value|
      states[id][key] = value[:total]
    end
  end
  index = {
    id: country[:id],
    name: country[:name],
    flag: country[:flag],
    badge: File.join(prefix, 'badge.svg'),
    states: Hash[states.sort_by { |key, value| value[:name] }],
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
    value[:series].values.last.each do |key, value|
      countries[id][key] = value[:total]
    end
  end
  index = {
    id: subregion[:id],
    name: subregion[:name],
    badge: File.join(prefix, 'badge.svg'),
    countries: Hash[countries.sort_by { |key, value| value[:name] }],
    series: subregion[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
  countries
end

def write_region(region, root, prefix)
  subregions = {}
  countries = {}
  region[:subregions].each do |key, value|
    next if key == :series
    id = key.downcase
    uri = File.join(prefix, id)
    countries.merge!(write_subregion(value, File.join(root, id), uri))
    subregions[id] = {
      id: key,
      name: value[:name],
      uri: "#{uri}.json"
    }
    value[:series].values.last.each do |key, value|
      subregions[id][key] = value[:total]
    end
  end
  index = {
    id: region[:id],
    name: region[:name],
    badge: File.join(prefix, 'badge.svg'),
    subregions: Hash[subregions.sort_by { |key, value| value[:name] }],
    series: region[:series]
  }
  write_file("#{root}.json", index)
  write_file(File.join(root, 'index.json'), index)
  countries
end

def write_world(world, root, prefix)
  regions = {}
  countries = {}
  world.each do |key, value|
    next if key == :series
    next if key.empty?
    id = key.downcase
    uri = File.join(prefix, id)
    countries.merge!(write_region(value, File.join(root, id), uri))
    regions[id] = {
      name: value[:name],
      uri: "#{uri}.json"
    }
    value[:series].values.last.each do |key, value|
      regions[id][key] = value[:total]
    end
  end
  index = {
    name: 'Global',
    badge: File.join(prefix, 'badge.svg'),
    regions: Hash[regions.sort_by { |key, value| value[:name] }],
    series: world[:series]
  }
  write_file(File.join(root, 'index.json'), index)
  countries = Hash[countries.sort_by { |key, value| value[:name] }]
  write_file(File.join(root, 'countries.json'), { countries: countries })
end

def generate_badges(data, root)
  data.each do |key, value|
    next unless value.is_a?(Hash)
    next if value.length.zero?
    next if key == :series
    if key.is_a?(Symbol)
      value.each do |key, value|
        next if key.is_a?(Symbol)
        id = key.downcase
        generate_badges(value, File.join(root, id))
      end
    else
      id = key.downcase
      generate_badges(value, File.join(root, id))
    end
  end
  return if data[:series].nil?
  today = nil
  data[:series].keys.reverse.each do |key|
    value = data[:series][key]
    path = File.join(root, "#{key}.svg")
    next if !today.nil? && File.exist?(path)
    today ||= path
    name = data[:name]&.downcase || "global"
    delta =
      if value[:confirmed][:delta] < 0
        "(#{value[:confirmed][:delta].abs})"
      else
        value[:confirmed][:delta].to_s
      end
    total = value[:confirmed][:total].to_s
    colour =
      case value[:confirmed][:growth]
      when -Float::INFINITY..0.2
        'success'
      when 0.2..0.5
        'informational'
      when 0.5..0.9
        'inactive'
      when 0.9..1.2
        'yellow'
      when 1.2..1.5
        'important'
      when 1.5..Float::INFINITY
        'critical'
      end
    url = URL.gsub('NAME', URI.encode(name).gsub(/[ -]/, '%20')).gsub('TOTAL', total).gsub('DELTA', URI.encode("Δ#{delta} → ")).gsub('COLOUR', colour)
    puts "Writing #{path}"
    blob = RestClient.get(url)
    if blob != (File.read(path) rescue "")
      puts "Writing #{path}"
      File.write(path, blob)
    end
    break
  end
  return if today.nil?
  FileUtils.cp(today, File.join(root, 'badge.svg'))
end

root = ARGV[0] || ENV.fetch('COVID19_PATH', nil) || File.join('..', 'COVID-19')
path = File.join(root, 'csse_covid_19_data', 'csse_covid_19_time_series')
raise "No such directory: #{path}" unless Dir.exist?(path)

world = {}
puts "*** ingest ***"
['confirmed', 'deaths'].each do |status|
  puts status
  name = "time_series_covid19_#{status}_global.csv"
  data = CSV.read(File.join(path, name), headers: true)
  total = 0
  data.each do |row|
    next if row["Country/Region"] == 'US'
    total += row[data.headers.last].to_i
    next unless node = add_row(world, row)
    node[:series] ||= {}
    process_series(node[:series], status.to_sym, data.headers, row)
  end
  puts total
end
puts "*** timeline ***"
['confirmed', 'deaths'].each do |status|
  puts "US #{status}"
  name = "time_series_covid19_#{status}_US.csv"
  data = CSV.read(File.join(path, name), headers: true)
  total = 0
  data.each do |row|
    total += row[data.headers.last].to_i
    next unless node = add_row(world, row)
    node[:series] ||= {}
    process_series(node[:series], status.to_sym, data.headers, row)
  end
  puts total
end
puts "*** states ***"
state_acronyms(world)
puts "*** cities ***"
city_acronyms(world)
puts "*** keys ***"
world = regenerate_keys(world)
puts "***series ***"
generate_series(world)
puts "*** metadata ***"
generate_metadata(world)
puts "*** world ***"
show_world(world)
write_world(world, 'www', 'https://corona.kranzky.com')
FileUtils.cp(File.join('www', 'index.json'), File.join('www', 'api.json'))
FileUtils.cp_r('src/.', 'www')
puts "*** badges ***"
generate_badges(world, 'www')

__END__
https://img.shields.io/badge/NAME-DELTA%20TOTAL-COLOUR?logo=data:image/png;base64,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
