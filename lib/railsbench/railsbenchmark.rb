require File.expand_path(File.dirname(__FILE__) + '/benchmark_specs')

class RailsBenchmark

  attr_accessor :gc_frequency, :iterations
  attr_accessor :http_host, :remote_addr, :server_port
  attr_accessor :relative_url_root
  attr_accessor :perform_caching, :cache_template_loading
  attr_accessor :session_data, :session_key, :cookie_data

  def error_exit(msg)
    STDERR.puts msg
    raise msg
  end

  def patched_gc?
    @patched_gc
  end

  def relative_url_root=(value)
    ActionController::AbstractRequest.relative_url_root = value
    @relative_url_root = value
  end

  def initialize(options={})
    unless @gc_frequency = options[:gc_frequency]
      @gc_frequency = 0
      ARGV.each{|arg| @gc_frequency = $1.to_i if arg =~ /-gc(\d+)/ }
    end

    @iterations = (options[:iterations] || 100).to_i

    @remote_addr = options[:remote_addr] || '127.0.0.1'
    @http_host =  options[:http_host] || '127.0.0.1'
    @server_port = options[:server_port] || '80'

    @session_data = options[:session_data] || {}
    @session_key = options[:session_key] || '_session_id'

    ENV['RAILS_ENV'] = 'benchmarking'

    begin
      require ENV['RAILS_ROOT'] + "/config/environment"
      require 'dispatcher' # make edge rails happy
    rescue => e
      $stderr.puts "failed to load application environment"
      e.backtrace.each{|line| $stderr.puts line}
      $stderr.puts "benchmarking aborted"
      exit(-1)
    end

    # we don't want local error template output, which crashes anyway, when run under railsbench
    ActionController::Rescue.class_eval "def local_request?; false; end"

    # print backtrace and exit if action execution raises an exception
    ActionController::Rescue.class_eval <<-"end_eval"
      def rescue_action_in_public(exception)
        $stderr.puts "benchmarking aborted due to application error: " + exception.message
        exception.backtrace.each{|line| $stderr.puts line}
        $stderr.print "clearing database connections ..."
        ActiveRecord::Base.send :clear_all_cached_connections! if ActiveRecord::Base.respond_to?(:clear_all_cached_connections)
        ActiveRecord::Base.clear_all_connections! if ActiveRecord::Base.respond_to?(:clear_all_connections)
        $stderr.puts
        exit!(-1)
      end
    end_eval

    # override rails ActiveRecord::Base#inspect to make profiles more readable
    ActiveRecord::Base.class_eval <<-"end_eval"
      def self.inspect
        super
      end
    end_eval

    # make sure Rails doesn't try to read post data from stdin
    CGI::QueryExtension.module_eval <<-end_eval
      def read_body(content_length)
        ENV['RAW_POST_DATA']
      end
    end_eval

    if ARGV.include?('-path')
      $:.each{|f| STDERR.puts f}
      exit
    end

    logger_module = Logger
    if defined?(Log4r) && RAILS_DEFAULT_LOGGER.is_a?(Log4r::Logger)
      logger_module = Logger
    end
    default_log_level = logger_module.const_get("ERROR")
    log_level = options[:log] || default_log_level
    ARGV.each do |arg|
        case arg
        when '-log'
          log_level = default_log_level
        when '-log=(nil|none)'
          log_level = nil
        when /-log=([a-zA-Z]*)/
          log_level = logger_module.const_get($1.upcase) rescue default_log_level
        end
    end

    if log_level
      RAILS_DEFAULT_LOGGER.level = log_level
      ActiveRecord::Base.logger.level = log_level
      ActionController::Base.logger.level = log_level
      ActionMailer::Base.logger = level = log_level if defined?(ActionMailer)
    else
      RAILS_DEFAULT_LOGGER.level = logger_module.const_get "FATAL"
      ActiveRecord::Base.logger = nil
      ActionController::Base.logger = nil
      ActionMailer::Base.logger = nil if defined?(ActionMailer)
    end

    if options.has_key?(:perform_caching)
      ActionController::Base.perform_caching = options[:perform_caching]
    else
      ActionController::Base.perform_caching = false if ARGV.include?('-nocache')
      ActionController::Base.perform_caching = true if ARGV.include?('-cache')
    end

    if ActionView::Base.respond_to?(:cache_template_loading)
      if options.has_key?(:cache_template_loading)
        ActionView::Base.cache_template_loading = options[:cache_template_loading]
      else
        ActionView::Base.cache_template_loading = true
      end
    end

    self.relative_url_root = options[:relative_url_root] || ''

    @patched_gc = GC.collections.is_a?(Numeric) rescue false

    if ARGV.include? '-headers_only'
      require File.dirname(__FILE__) + '/write_headers_only'
    end

  end

  def establish_test_session
    session_options = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS.stringify_keys
    session_options = session_options.merge('new_session' => true)
    @session = CGI::Session.new(Hash.new, session_options)
    @session_data.each{ |k,v| @session[k] = v }
    @session.update
    @session_id = @session.session_id
  end

  def update_test_session_data(session_data)
    dbman = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS[:database_manager]
    old_session_data = dbman.new(@session).restore
    # $stderr.puts old_session_data.inspect
    new_session_data = old_session_data.merge(session_data || {})
    new_session_data.each{ |k,v| @session[k] = v }
    @session.update
  end

  def delete_test_session
    @session.delete
    @session = nil
  end

  # can be redefined in subclasses to clean out test sessions
  def delete_new_test_sessions
  end

  def setup_test_urls(name)
    @benchmark = name
    @urls = BenchmarkSpec.load(name)
  end

  def setup_initial_env
    ENV['REMOTE_ADDR'] = remote_addr
    ENV['HTTP_HOST'] = http_host
    ENV['SERVER_PORT'] = server_port.to_s
  end

  def setup_request_env(entry)
    # $stderr.puts entry.inspect
    ENV['REQUEST_URI'] = @relative_url_root + entry.uri
    ENV.delete 'RAW_POST_DATA'
    ENV.delete 'QUERY_STRING'
    case ENV['REQUEST_METHOD'] = (entry.method || 'get').upcase
    when 'GET'
      query_data = entry.query_string || ''
      query_data = escape_data(query_data) unless entry.raw_data
      ENV['QUERY_STRING'] = query_data
    when 'POST'
      query_data = entry.post_data || ''
      query_data = escape_data(query_data) unless entry.raw_data
      ENV['RAW_POST_DATA'] = query_data
    end
    ENV['CONTENT_LENGTH'] = query_data.length.to_s
    ENV['HTTP_COOKIE'] = entry.new_session ? '' : cookie
    ENV['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest' if entry.xhr
    # $stderr.puts entry.session_data.inspect
    update_test_session_data(entry.session_data) unless entry.new_session
  end

  def cookie
    "#{@session_key}=#{@session_id}#{cookie_data}"
  end

  def escape_data(str)
    str.split('&').map{|e| e.split('=').map{|e| CGI::escape e}.join('=')}.join('&')
  end

  def warmup
    error_exit "No urls given for performance test" unless @urls && @urls.size>0
    setup_initial_env
    @urls.each do |entry|
      error_exit "No uri given for benchmark entry: #{entry.inspect}" unless entry.uri
      setup_request_env(entry)
      Dispatcher.dispatch
    end
  end

  def run_urls_without_benchmark(gc_stats)
    # support for running Ruby Performance Validator
    # or Ruby Memory Validator
    svl = nil
    begin
      if ARGV.include?('-svlPV')
        require 'svlRubyPV'
        svl = SvlRubyPV.new
      elsif ARGV.include?('-svlMV')
        require 'svlRubyMV'
        svl = SvlRubyMV
      end
    rescue LoadError
      # SVL dll not available, do nothing
    end

    # support ruby-prof
    ruby_prof = nil
    ARGV.each{|arg| ruby_prof=$1 if arg =~ /-ruby_prof=([^ ]*)/ }
    begin
      if ruby_prof
        # redirect stderr
        if benchmark_file = ENV['RAILS_BENCHMARK_FILE']
          $stderr = File.open(benchmark_file, "w")
        end
        require 'ruby-prof'
        RubyProf.measure_mode = RubyProf::WALL_TIME
        RubyProf.start
      end
    rescue LoadError
      # ruby-prof not available, do nothing
      $stderr = STDERR
      $stderr.puts "ruby-prof not available: giving up"
      exit(-1)
    end

    # start profiler and trigger data collection if required
    if svl
      svl.startProfiler
      svl.startDataCollection
    end

    setup_initial_env
    GC.enable_stats if gc_stats
    if gc_frequency==0
      run_urls_without_benchmark_and_without_gc_control(@urls, iterations)
    else
      run_urls_without_benchmark_but_with_gc_control(@urls, iterations, gc_frequency)
    end
    if gc_stats
      GC.enable if gc_frequency
      GC.start
      GC.dump
      GC.disable_stats
      GC.log "number of requests processed: #{@urls.size * iterations}"
    end

    # try to detect Ruby interpreter memory leaks (OS X)
    if ARGV.include?('-leaks')
      leaks_log = "#{ENV['RAILS_PERF_DATA']}/leaks.log"
      leaks_command = "leaks -nocontext #{$$} >#{leaks_log}"
      ENV.delete 'MallocStackLogging'
      # $stderr.puts "executing '#{leaks_command}'"
      raise "could not execute leaks command" unless system(leaks_command)
      mallocs, leaks = *`head -n 2 #{leaks_log}`.split("\n").map{|l| l.gsub(/Process #{$$}: /, '')}
      if mem_leaks = (leaks =~ /(\d+) leaks for (\d+) total leaked bytes/)
        $stderr.puts "\n!!!!! memory leaks detected !!!!! (#{leaks_log})"
        $stderr.puts "=" * leaks.length
      end
      if gc_stats
        GC.log mallocs
        GC.log leaks
      end
      $stderr.puts mallocs, leaks
      $stderr.puts "=" * leaks.length if mem_leaks
    end

    # stop data collection if necessary
    svl.stopDataCollection if svl

    if defined? RubyProf
      GC.disable #ruby-pof 0.7.x crash workaround
      result = RubyProf.stop
      GC.enable  #ruby-pof 0.7.x crash workaround
      min_percent = ruby_prof.split('/')[0].to_f rescue 1.0
      threshold = ruby_prof.split('/')[1].to_f rescue 3.0
      profile_type = nil
      ARGV.each{|arg| profile_type=$1 if arg =~ /-profile_type=([^ ]*)/ }
      if profile_type =~ /stack/
        printer = RubyProf::CallStackPrinter.new(result)
      else
        printer = RubyProf::GraphHtmlPrinter.new(result)
      end
      printer.print($stderr, :min_percent => min_percent, :threshold => threshold, :title => "call tree for benchmark #{@benchmark}")
    end

    delete_test_session
    delete_new_test_sessions
  end

  def run_urls(test)
    setup_initial_env
    if gc_frequency>0
      run_urls_with_gc_control(test, @urls, iterations, gc_frequency)
    else
      run_urls_without_gc_control(test, @urls, iterations)
    end
    delete_test_session
    delete_new_test_sessions
  end

  def run_url_mix(test)
    if gc_frequency>0
      run_url_mix_with_gc_control(test, @urls, iterations, gc_frequency)
    else
      run_url_mix_without_gc_control(test, @urls, iterations)
    end
    delete_test_session
    delete_new_test_sessions
  end

  private

  def run_urls_without_benchmark_but_with_gc_control(urls, n, gc_frequency)
    urls.each do |entry|
      setup_request_env(entry)
      GC.enable; GC.start; GC.disable
      request_count = 0
      n.times do
        Dispatcher.dispatch
        if (request_count += 1) == gc_frequency
          GC.enable; GC.start; GC.disable
          request_count = 0
        end
      end
    end
  end

  def run_urls_without_benchmark_and_without_gc_control(urls, n)
    urls.each do |entry|
      setup_request_env(entry)
      n.times do
        Dispatcher.dispatch
      end
    end
  end

  def run_urls_with_gc_control(test, urls, n, gc_freq)
    gc_stats = patched_gc?
    GC.clear_stats if gc_stats
    urls.each do |entry|
      request_count = 0
      setup_request_env(entry)
      test.report(entry.name) do
        GC.disable_stats if gc_stats
        GC.enable; GC.start; GC.disable
        GC.enable_stats  if gc_stats
        n.times do
          Dispatcher.dispatch
          if (request_count += 1) == gc_freq
            GC.enable; GC.start; GC.disable
            request_count = 0
          end
        end
      end
    end
    if gc_stats
      GC.disable_stats
      Benchmark::OUTPUT.puts "GC.collections=#{GC.collections}, GC.time=#{GC.time/1E6}"
      GC.clear_stats
    end
  end

  def run_urls_without_gc_control(test, urls, n)
    gc_stats = patched_gc?
    GC.clear_stats if gc_stats
    urls.each do |entry|
      setup_request_env(entry)
      GC.disable_stats if gc_stats
      GC.start
      GC.enable_stats  if gc_stats
      test.report(entry.name) do
        n.times do
          Dispatcher.dispatch
        end
      end
    end
    if gc_stats
      GC.disable_stats
      Benchmark::OUTPUT.puts "GC.collections=#{GC.collections}, GC.time=#{GC.time/1E6}"
      GC.clear_stats
    end
  end

  def run_url_mix_without_gc_control(test, urls, n)
    gc_stats = patched_gc?
    GC.start
    if gc_stats
      GC.clear_stats; GC.enable_stats
    end
    test.report("url_mix (#{urls.length} urls)") do
      n.times do
        urls.each do |entry|
          setup_request_env(entry)
          Dispatcher.dispatch
        end
      end
    end
    if gc_stats
      GC.disable_stats
      Benchmark::OUTPUT.puts "GC.collections=#{GC.collections}, GC.time=#{GC.time/1E6}"
      GC.clear_stats
    end
  end

  def run_url_mix_with_gc_control(test, urls, n, gc_frequency)
    gc_stats = patched_gc?
    GC.enable; GC.start; GC.disable
    if gc_stats
      GC.clear_stats; GC.enable_stats
    end
    test.report("url_mix (#{urls.length} urls)") do
      request_count = 0
      n.times do
        urls.each do |entry|
          setup_request_env(entry)
          Dispatcher.dispatch
          if (request_count += 1) == gc_frequency
            GC.enable; GC.start; GC.disable
            request_count = 0
          end
        end
      end
    end
    if gc_stats
      GC.disable_stats
      Benchmark::OUTPUT.puts "GC.collections=#{GC.collections}, GC.time=#{GC.time/1E6}"
      GC.clear_stats
    end
  end
end


class RailsBenchmarkWithActiveRecordStore < RailsBenchmark

  def initialize(options={})
    super(options)
    @session_class = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS[:database_manager].session_class rescue CGI::Session::ActiveRecordStore
  end

  def delete_new_test_sessions
    @session_class.delete_all if @session_class.respond_to?(:delete_all)
  end

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
