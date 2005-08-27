#!/usr/local/bin/ruby

require 'fileutils'
if ARGV.include?('--dry-run')
  include FileUtils::DryRun
else
  include FileUtils::Verbose
end

require 'yaml'

unless RAILS_ROOT = ENV['RAILS_ROOT']
  STDERR.puts "RAILS_ROOT must be fined in your environement"
  exit 1
end

RAILS_CONFIG = RAILS_ROOT + "/config/"
RAILS_ENVS = RAILS_ROOT + "/config/environments/"

install("config/benchmarks.rb", RAILS_CONFIG, :mode => 0644) unless
  File.exists?(RAILS_CONFIG + "benchmarks.rb")

install("config/benchmarks.yml", RAILS_CONFIG, :mode => 0644) unless
  File.exists?(RAILS_CONFIG + "benchmarks.yml")

install("config/benchmarking.rb", RAILS_ENVS, :mode => 0644) unless
  File.exists?(RAILS_ENVS + "benchmarking.rb")

database = YAML::load(File.open(RAILS_CONFIG + "database.yml"))
unless database["benchmarking"]
  puts "creating database configuration: benchmarking"
  File.open(RAILS_CONFIG + "database.yml", "ab") do |file|
    file.puts "\nbenchmarking:\n"
    %w(adapter database host username password).each do |k|
      file.puts "  #{k}: #{database['development'][k]}"
    end
  end
end
