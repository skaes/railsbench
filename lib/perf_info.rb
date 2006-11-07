require "#{File.dirname(__FILE__)}/perf_utils.rb"

# example of raw performance data

# /home/skaes/railsbench/script/perf_bench 100 -bm=all -mysql_session -patched_gc -links -OT
#                                       user     system      total        real
# loading environment               0.954000   1.938000   2.892000 (  2.890000)
# /empty/index                      0.093000   0.000000   0.093000 (  0.172000)
# /welcome/index                    0.156000   0.000000   0.156000 (  0.172000)
# /rezept/index                     0.125000   0.015000   0.140000 (  0.203000)
# /rezept/myknzlpzl                 0.125000   0.000000   0.125000 (  0.203000)
# /rezept/show/413                  0.406000   0.094000   0.500000 (  0.594000)
# /rezept/cat/Hauptspeise           0.547000   0.094000   0.641000 (  0.688000)
# /rezept/cat/Hauptspeise?page=5    0.531000   0.047000   0.578000 (  0.688000)
# /rezept/letter/G                  0.422000   0.078000   0.500000 (  0.609000)
# GC.collections=0, GC.time=0.0
#                                       user     system      total        real
# loading environment               0.813000   2.078000   2.891000 (  2.890000)
# /empty/index                      0.125000   0.016000   0.141000 (  0.157000)
# /welcome/index                    0.109000   0.000000   0.109000 (  0.187000)
# /rezept/index                     0.110000   0.031000   0.141000 (  0.219000)
# /rezept/myknzlpzl                 0.109000   0.016000   0.125000 (  0.219000)
# /rezept/show/413                  0.422000   0.078000   0.500000 (  0.625000)
# /rezept/cat/Hauptspeise           0.437000   0.125000   0.562000 (  0.656000)
# /rezept/cat/Hauptspeise?page=5    0.453000   0.125000   0.578000 (  0.688000)
# /rezept/letter/G                  0.438000   0.000000   0.438000 (  0.594000)
# GC.collections=0, GC.time=0.0
#                                       user     system      total        real
# loading environment               0.938000   1.968000   2.906000 (  2.906000)
# /empty/index                      0.109000   0.000000   0.109000 (  0.172000)
# /welcome/index                    0.094000   0.031000   0.125000 (  0.171000)
# /rezept/index                     0.110000   0.047000   0.157000 (  0.219000)
# /rezept/myknzlpzl                 0.140000   0.016000   0.156000 (  0.203000)
# /rezept/show/413                  0.422000   0.047000   0.469000 (  0.593000)
# /rezept/cat/Hauptspeise           0.515000   0.015000   0.530000 (  0.672000)
# /rezept/cat/Hauptspeise?page=5    0.484000   0.063000   0.547000 (  0.672000)
# /rezept/letter/G                  0.453000   0.015000   0.468000 (  0.610000)
# GC.collections=0, GC.time=0.0


PerfAttributes = [:gc_calls, :gc_time, :load_time, :total_time]
PerfSummaries  = [:min, :max, :mean, :stddev, :stddev_percentage]

class PerfEntry
  attr_accessor *PerfAttributes
  attr_accessor :keys, :timings
  def initialize
    @keys = []
    @timings = {}
  end
end

class PerfInfo

  attr_reader :options, :iterations, :keys
  attr_reader :entries, :runs, :request_count, :requests_per_key

  def gc_stats?
    @gc_stats
  end

  PerfSummaries.each do |method|
    PerfAttributes.each do |attr|
      attr_reader "#{attr}_#{method}"
    end
    class_eval "def timings_#{method}(key); @timings[:#{method}][key]; end"
  end

  def initialize(file)
    @entries = []
    file.each_line do |line|
      case line
      when /^.*perf_([a-zA-Z.]+)\s+(\d+)\s+(.*)$/
        @iterations = $2.to_i
        @options = $3
      when /\s+user\s+system\s+total\s+real/
        @entries << PerfEntry.new
      when /^(.*)\s+([\d\.]+)\s+([\d\.]+)\s+([\d\.]+)\s+\(\s*([\d\.]+)\s*\)$/
        key, time = $1.strip, $5.to_f
        if key == "loading environment"
          @entries.last.load_time = time
        else
          @entries.last.keys << key
          @entries.last.timings[key] = time
        end
      when /^GC.collections=(\d+), GC.time=([\d\.]+)$/
        @entries.last.gc_calls, @entries.last.gc_time = [$1.to_i,$2.to_f]
        @gc_stats = true
      end
    end

    @entries.each{ |e| e.total_time =  e.timings.values.sum }
    @keys = @entries.first.keys
    @runs = @entries.length
    if @keys.length == 1 && @keys[0] =~ /\((\d+) urls\)$/
      @requests_per_key = $1.to_i
    else
      @requests_per_key = 1
    end
    @request_count = @iterations * @keys.length * @requests_per_key
    @timings = PerfSummaries.inject({}){ |hash, method| hash[method] = Hash.new; hash }

    @keys.each do |k|
      a = @entries.map{|e| e.timings[k]}
      [:min, :max, :mean].each do |method|
        @timings[method][k] = a.send(method)
      end
      mean = @timings[:mean][k]
      stddev = @timings[:stddev][k] = a.send(:stddev, mean)
      @timings[:stddev_percentage][k] = stddev_percentage(stddev, mean)
    end

    PerfAttributes.each do |attr|
      a = @entries.map{|e| e.send attr}
      [:min, :max, :mean].each do |method|
        instance_variable_set "@#{attr}_#{method}", (a.send method)
      end
      mean = instance_variable_get "@#{attr}_mean"
      stddev = instance_variable_set "@#{attr}_stddev", (a.send :stddev, mean)
      instance_variable_set "@#{attr}_stddev_percentage", stddev_percentage(stddev, mean)
    end

  end
end


### Local Variables: ***
### mode:ruby ***
### End: ***

#    Copyright (C) 2006  Stefan Kaes
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
