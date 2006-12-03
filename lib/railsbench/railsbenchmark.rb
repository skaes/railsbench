class RailsBenchmark

  attr_accessor :gc_frequency, :iterations, :url_spec
  attr_accessor :http_host, :remote_addr, :server_port
  attr_accessor :relative_url_root
  attr_accessor :perform_caching, :cache_template_loading
  attr_accessor :session_data

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

    @url_spec = options[:url_spec]

    ENV['RAILS_ENV'] = 'benchmarking'

    require ENV['RAILS_ROOT'] + "/config/environment"
    require 'dispatcher' # make edge rails happy

    # we don't want local error template output, which crashes anyway
    ActionController::Rescue.class_eval "def local_request?; false; end"

    # make sure an error code gets returned for 1.1.6
    ActionController::Rescue.class_eval <<-"end_eval"
      def rescue_action_in_public(exception)
        case exception
          when ActionController::RoutingError, ActionController::UnknownAction
            render_text(IO.read(File.join(RAILS_ROOT, 'public', '404.html')), "404 Not Found")
          else
            render_text(IO.read(File.join(RAILS_ROOT, 'public', '500.html')), "500 Internal Error")
        end
      end
    end_eval

    if ARGV.include?('-path')
      $:.each{|f| STDERR.puts f}
      exit
    end

    log_level = options[:log]
    log_level = Logger::DEBUG if ARGV.include?('-log')
    ARGV.each{|arg| arg =~ /-log=([a-zA-Z]*)/ && (log_level = eval("Logger::#{$1.upcase}")) }

    if log_level
      RAILS_DEFAULT_LOGGER.level = log_level
      #ActiveRecord::Base.logger.level = log_level
      #ActionController::Base.logger.level = log_level
      #ActionMailer::Base.logger = level = log_level if defined?(ActionMailer)
    else
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

    if options.has_key?(:cache_template_loading)
      ActionView::Base.cache_template_loading = options[:cache_template_loading]
    else
      ActionView::Base.cache_template_loading = true
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

  def delete_test_session
    @session.delete
    @session = nil
  end

  # can be redefined in subclasses to clean out test sessions
  def delete_new_test_sessions
  end

  def setup_test_urls(name)
    raise "There is no benchmark named '#{name}'" unless @url_spec[name]
    @urls = self.class.parse_url_spec(@url_spec, name)
  end

  def setup_initial_env
    ENV['REMOTE_ADDR'] = remote_addr
    ENV['HTTP_HOST'] = http_host
    ENV['SERVER_PORT'] = server_port.to_s
    ENV['REQUEST_METHOD'] = 'GET'
  end

  def setup_request_env(uri, query_string, new_session)
    ENV['REQUEST_URI'] = @relative_url_root + uri
    ENV['QUERY_STRING'] = query_string || ''
    ENV['CONTENT_LENGTH'] = (query_string || '').length.to_s
    ENV['HTTP_COOKIE'] = new_session ? '' : "_session_id=#{@session_id}"
  end

  def warmup
    error_exit "No urls given for performance test" unless @urls && @urls.size>0
    setup_initial_env
    @urls.each do |entry|
      error_exit "No uri given for benchmark entry: #{entry.inspect}" unless entry['uri']
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
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
        svl = SvlRubyMV.new
      end
    rescue LoadError
      # SVL dll not available, do nothing
    end

    # support ruby-prof
    ruby_prof = nil
    ARGV.each{|arg| ruby_prof=$1 if arg =~ /-ruby_prof=(\d*\.?\d*)/ }
    begin
      if ruby_prof
        require 'ruby-prof'
        RubyProf.clock_mode = RubyProf::WALL_TIME
        RubyProf.start
      end
    rescue LoadError
      # ruby-prof not available, do nothing
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

    # stop data collection if necessary
    svl.stopDataCollection if svl

    if defined? RubyProf
      result = RubyProf.stop
      # Print a flat profile to text
      printer = RubyProf::GraphHtmlPrinter.new(result)
      printer.print(STDERR, ruby_prof.to_f)
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
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
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
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
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
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
      test.report(entry['uri']) do
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
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
      GC.disable_stats if gc_stats
      GC.start
      GC.enable_stats  if gc_stats
      test.report(entry['uri']) do
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
          setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
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
          setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
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

  def self.parse_url_spec(url_spec, name)
    res = url_spec[name]
    if res.is_a?(String)
      res = res.split(/, */).collect!{ |n| parse_url_spec(url_spec, n) }.flatten
    elsif res.is_a?(Hash)
      res = [ res ]
    end
    res
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
