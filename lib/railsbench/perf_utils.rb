# some utility methods

class Array
  def index_map
    res = {}
    each_with_index{|element, index| res[index] = element}
    res
  end

  def restrict_to(index_set)
    res = []
    each_with_index{|e,i| res << e if index_set.include?(i)}
    res
  end

  def sum
    inject(0.0){|r,v| r += v }
  end

  def mean
    sum/length
  end

  def stddev(mean=nil)
    mean ||= self.mean
    r = inject(0.0){|r,v| r += (v-mean)*(v-mean) }
    Math.sqrt(r/(length-1))
  end
end

def stddev_percentage(stddev, mean)
  stddev.zero? ? 0.0 : (stddev/mean)*100
end

def determine_rails_root_or_die!(msg=nil)
  unless ENV['RAILS_ROOT']
    if File.directory?("config") && File.exists?("config/environment.rb")
      ENV['RAILS_ROOT'] = File.expand_path(".")
    else
      die(msg || "#{File.basename $PROGRAM_NAME}: $RAILS_ROOT not set and could not be configured automatically")
    end
  end
end

def die(msg, error_code=1)
  $stderr.puts msg
  exit error_code
end

class File
  def self.open_or_die(filename, &block)
    filename = filename.sub(/^\/([cdefgh])(\/)/, '\1:\2') if RUBY_PLATFORM =~ /win32/
    begin
      if stat(filename).readable?
        open(filename, &block)
      else
        die "file #{filename} is unreadable"
      end
    rescue
      die "file #{filename} does not exist"
    end
  end
end

def truncate(text, length = 32, truncate_string = "...")
  if text.nil? then return "" end
  l = truncate_string.length + 1

  if RUBY_VERSION !~ /1.9/ && $KCODE == "NONE"
    text.length > length ? text[0..(length - l)] + truncate_string : text
  else
    chars = text.split(//)
    chars.length > length ? chars[0..(length - l)].join + truncate_string : text
  end
end

RAILSBENCH_BINDIR = File.expand_path(File.dirname(__FILE__) + "/../../script")

def enable_gc_stats(file)
  ENV['RUBY_GC_STATS'] = "1"
  ENV['RUBY_GC_DATA_FILE'] = file
end

def disable_gc_stats
  ENV.delete 'RUBY_GC_STATS'
  ENV.delete 'RUBY_GC_DATA_FILE'
end

def unset_gc_variables
  %w(RUBY_HEAP_MIN_SLOTS RUBY_GC_MALLOC_LIMIT RUBY_HEAP_FREE_MIN).each{|v| ENV.delete v}
end

def load_gc_variables(gc_spec)
  File.open_or_die("#{ENV['RAILS_ROOT']}/config/#{gc_spec}.gc").each_line do |line|
    ENV[$1] = $2 if line =~ /^(.*)=(.*)$/
  end
end

def set_gc_variables(argv)
  gc_spec = nil
  argv.each{|arg| gc_spec=$1 if arg =~ /-gc=([^ ]*)/}

  if gc_spec
    load_gc_variables(gc_spec)
  else
    unset_gc_variables
  end
end

def benchmark_file_name(benchmark, config_name, prefix=nil, suffix=nil)
  perf_data_dir = (ENV['RAILS_PERF_DATA'] ||= ENV['HOME'])
  date = Time.now.strftime '%m-%d'
  suffix = ".#{suffix}" if suffix
  ENV['RAILS_BENCHMARK_FILE'] =
    if config_name
      "#{perf_data_dir}/#{date}.#{benchmark}.#{config_name}#{suffix}.txt"
    else
      "#{perf_data_dir}/perf_run#{prefix}.#{benchmark}#{suffix}.txt"
    end
end

def quote_arguments(argv)
  argv.map{|a| a.include?(' ') ? "'#{a}'" : a.to_s}.join(' ')
end

def perf_run(script, iterations, options, raw_data_file)
  perf_runs = (ENV['RAILS_PERF_RUNS'] ||= "3").to_i

  disable_gc_stats
  set_gc_variables([iterations, options])

  perf_options = "#{iterations} #{options}"
  null = (RUBY_PLATFORM =~ /win32/i) ? 'nul' : '/dev/null'

  perf_cmd = "ruby #{RAILSBENCH_BINDIR}/perf_bench #{perf_options}"
  print_cmd = "ruby #{RAILSBENCH_BINDIR}/perf_times #{raw_data_file}"

  puts "benchmarking #{perf_runs} runs with options #{perf_options}"

  File.open(raw_data_file, "w"){ |f| f.puts perf_cmd }
  perf_runs.times do
    system("#{perf_cmd} >#{null}") || die("#{script}: #{perf_cmd} returned #{$?}")
  end
  File.open(raw_data_file, "a" ){|f| f.puts }

  unset_gc_variables
  system(print_cmd) || die("#{script}: #{print_cmd} returned #{$?}")
end

def perf_run_gc(script, iterations, options, raw_data_file)
  warmup = "-warmup"
  warmup = "" if options =~ /-warmup/

  enable_gc_stats(raw_data_file)
  set_gc_variables([options])

  perf_options = "#{iterations} #{warmup} #{options}"
  null = (RUBY_PLATFORM =~ /win32/) ? 'nul' : '/dev/null'

  perf_cmd = "ruby #{RAILSBENCH_BINDIR}/run_urls #{perf_options} >#{null}"
  print_cmd = "ruby #{RAILSBENCH_BINDIR}/perf_times_gc #{raw_data_file}"

  if options =~ /-leaks/
    if RUBY_PLATFORM =~ /darwin9/
      puts "enabling MallocStackLogging"
      perf_cmd.insert(0, "MallocStackLogging=1 ")
    else
      die "leak debugging not supported on #{RUBY_PLATFORM}"
    end
  end

  puts "benchmarking GC performance with options #{perf_options}"
  puts

  system(perf_cmd) || die("#{script}: #{perf_cmd} returned #{$?}")

  disable_gc_stats
  unset_gc_variables
  system(print_cmd) || die("#{script}: #{print_cmd} returned #{$?}")
end

__END__

#  Copyright (C) 2005-2008  Stefan Kaes
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
