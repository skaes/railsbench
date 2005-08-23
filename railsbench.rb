class RailsBenchmark

  attr_accessor :gc_frequency, :iterations, :url_spec
  attr_accessor :http_host, :remote_addr, :server_port
  attr_accessor :perform_caching, :cache_template_loading
  attr_accessor :session_id, :session_data

  def error_exit(msg)
    STDERR.puts msg
    raise msg
  end
  
  def initialize(options)
    unless @gc_frequency = options[:gc_frequency]
      @gc_frequency = 0
      ARGV.each{|arg| @gc_frequency = $1.to_i if arg =~ /-gc(\d+)/ }
    end
    
    @iterations = (options[:iterations] || 100).to_i
    
    @remote_addr = options[:remote_addr] || '127.0.0.1'
    @http_host =  options[:http_host] || '127.0.0.1'
    @server_port = options[:server_port] || '80'

    @session_id = options[:session_id] || 'test_session_test_session_!!!!!!'
    @session_data = options[:session_data] || {}

    @url_spec = options[:url_spec]
    
    ENV['RAILS_ENV'] = 'performance'
    
    require ENV['RAILS_ROOT'] + "/config/environment"
    
    if ARGV.include?('-path')
      $:.each{|f| STDERR.puts f}
      exit
    end
    
    unless (options.has_key?(:log) && options[:log]) || ARGV.include?('-log')
      ActiveRecord::Base.logger = nil
      ActionController::Base.logger = nil
      ActionMailer::Base.logger = nil if defined?(ActionMailer)
    end

    if options.has_key?(:perform_caching)
      ActionController::Base.perform_caching = options[:perform_caching]
    else
      ActionController::Base.perform_caching = !ARGV.include?('-nocache')
    end

    if options.has_key?(:cache_template_loading)
      ActionView::Base.cache_template_loading = options[:cache_template_loading]
    else
      ActionView::Base.cache_template_loading = true
    end
  end

  # redefine in subclasses
  def establish_test_session
  end

  # redefine in subclasses
  def delete_all_test_sessions
  end

  # redefine in subclasses
  def delete_test_session
  end

  # redefine in subclasses
  def delete_new_test_sessions
  end

  def setup_test_urls(name)
    @urls = self.class.parse_url_spec(@url_spec, name)
  end

  def setup_initial_env
    ENV['REMOTE_ADDR'] = remote_addr
    ENV['HTTP_HOST'] = http_host
    ENV['SERVER_PORT'] = server_port.to_s
    ENV['REQUEST_METHOD'] = 'GET'
  end

  def setup_request_env(uri, query_string, new_session)
    ENV['REQUEST_URI'] = uri
    ENV['QUERY_STRING'] = query_string || ''
    ENV['CONTENT_LENGTH'] = (query_string || '').length.to_s
    ENV['HTTP_COOKIE'] = new_session ? '' : "_session_id=#{@session_id}"
  end

  def warmup
    error_exit "No urls given for performance test" unless @urls && @urls.size>0
    setup_initial_env
    @urls.each do |entry|
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
      Dispatcher.dispatch
    end
  end

  def run_urls_without_benchmark
    setup_initial_env
    if gc_frequency==0
      run_urls_without_benchmark_and_without_gc_control(@urls, iterations)
    else
      run_urls_without_benchmark_but_with_gc_control(@urls, iterations, gc_frequency)
    end
  end

  def run_urls(test)
    setup_initial_env
    if gc_frequency>0
      run_urls_with_gc_control(test, @urls, iterations, gc_frequency)
    else
      run_urls_without_gc_control(test, @urls, iterations)
    end
    delete_all_test_sessions
  end
    
  def run_url_mix(test)
    if gc_frequency>0
      run_url_mix_with_gc_control(test, @urls, iterations, gc_frequency)
    else
      run_url_mix_without_gc_control(test, @urls, iterations)
    end
    delete_all_test_sessions
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
    urls.each do |entry|
      request_count = 0
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
      test.report(entry['uri']) do
        GC.enable; GC.start; GC.disable
        n.times do
          Dispatcher.dispatch
          if (request_count += 1) == gc_freq
            GC.enable; GC.start; GC.disable
            request_count = 0
          end
        end
      end
      delete_new_test_sessions
    end
  end

  def run_urls_without_gc_control(test, urls, n)  
    urls.each do |entry|
      setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
      GC.start
      test.report(entry['uri']) do
        n.times do
          Dispatcher.dispatch
        end
      end
      delete_new_test_sessions
    end
  end
  
  def run_url_mix_without_gc_control(test, urls, n)
    test.report("url_mix (#{urls.length} urls)") do
      n.times do
        urls.each do |entry|
          setup_request_env(entry['uri'], entry['query_string'], entry['new_session'])
          Dispatcher.dispatch
        end
      end
    end
  end
  
  def run_url_mix_with_gc_control(test, urls, n, gc_frequency)
    test.report("url_mix (#{urls.length} urls)") do
      GC.enable; GC.start; GC.disable
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

  def initialize(options)
    super(options)
    @session_class = ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS[:database_manager].session_class
    @session_id_column = options[:session_id_column] || 'session_id'
  end

  def delete_all_test_sessions
    @session_class.delete_all
  end

  def delete_test_session
    @session_class.delete_all("#{@session_id_column}='#{@session_id}'")
  end

  def delete_new_test_sessions
    @session_class.delete_all("#{@session_id_column}!='#{@session_id}'")
  end

  def establish_test_session
    # make sure we are connected
    error_exit "Cannot connect!" unless @session_class.connection
    unless test_session = @session_class.find_by_session_id(@session_id)
      test_session = @session_class.new(:session_id => @session_id, :sessid => @session_id, :data => @session_data)
      test_session.data  # make sure data gets assigned
      test_session.save! # and store it in the DB
      # make sure it was properly saved
      unless saved_session = @session_class.find_by_session_id(@session_id)
        error_exit "test session was not properly stored to the DB!"
      end
    end 
  end

end


__END__

#  Copyright (C) 2005  Stefan Kaes
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
