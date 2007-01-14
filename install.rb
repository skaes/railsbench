#!/usr/bin/env ruby

require 'fileutils'
if ARGV.include?('--dry-run')
  include FileUtils::DryRun
else
  include FileUtils::Verbose
end

require 'yaml'

unless ENV['RAILS_ROOT']
  if File.exists? "config/environment.rb"
    ENV['RAILS_ROOT'] = File.expand_path "."
  else
    $stderr.puts "RAILS_ROOT must be fined in your environment"
    exit 1
  end
end

RAILS_ROOT = ENV['RAILS_ROOT']
RAILS_CONFIG = RAILS_ROOT + "/config/"
RAILS_ENVS = RAILS_ROOT + "/config/environments/"
RAILSBENCH_BASE = File.expand_path(File.dirname(__FILE__)) unless defined? RAILSBENCH_BASE

if ARGV.first == 'help'
  File.open("#{RAILSBENCH_BASE}/INSTALL").each_line{|l| puts l}
end

install("#{RAILSBENCH_BASE}/config/benchmarks.rb", RAILS_CONFIG, :mode => 0644) unless
  File.exists?(RAILS_CONFIG + "benchmarks.rb")

install("#{RAILSBENCH_BASE}/config/benchmarks.yml", RAILS_CONFIG, :mode => 0644) unless
  File.exists?(RAILS_CONFIG + "benchmarks.yml")

install("#{RAILSBENCH_BASE}/config/benchmarking.rb", RAILS_ENVS, :mode => 0644) unless
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

__END__

### Local Variables: ***
### mode:ruby ***
### End: ***

#  Copyright (C) 2005, 2006  Stefan Kaes
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
