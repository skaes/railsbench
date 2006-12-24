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

  if $KCODE == "NONE"
    text.length > length ? text[0..(length - l)] + truncate_string : text
  else
    chars = text.split(//)
    chars.length > length ? chars[0..(length - l)].join + truncate_string : text
  end
end

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

def quote_arguments(argv)
  argv.map{|a| a.include?(' ') ? "'#{a}'" : a.to_s}.join(' ')
end

def perf_loop(argv)
  bindir = File.expand_path(File.dirname(__FILE__) + '/../../script')

  iterations = (ENV['RAILS_PERF_RUNS'] ||= "3").to_i
  raw_data_file = ENV['RAILS_BENCHMARK_FILE']

  disable_gc_stats
  set_gc_variables(argv)

  null = (RUBY_PLATFORM =~ /win32/i) ? 'nul' : '/dev/null'
  perf_cmd = "ruby #{bindir}/perf_bench #{argv.join(' ')}"

  puts "benchmarking #{iterations} runs with options #{argv.join(' ')}"

  File.open(raw_data_file, "w"){ |f| f.puts perf_cmd }
  iterations.times do
    system("#{perf_cmd} >#{null}") || exit(1)
  end
  File.open(raw_data_file, "a" ){|f| f.puts }
end
