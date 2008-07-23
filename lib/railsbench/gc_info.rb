require File.expand_path(File.dirname(__FILE__) + "/perf_utils.rb")
require "set"

# Entry Format:
#
# Garbage collection started
# objects processed: 0223696
# live objects     : 0192126
# freelist objects : 0000000
# freed objects    : 0031570
# kept 0000370 / freed 0000609 objects of type OBJECT
# kept 0001071 / freed 0000062 objects of type CLASS
# kept 0000243 / freed 0000061 objects of type ICLASS
# kept 0000041 / freed 0000061 objects of type FLOAT
# kept 0013974 / freed 0015432 objects of type STRING
# kept 0000651 / freed 0000002 objects of type REGEXP
# kept 0000617 / freed 0009948 objects of type ARRAY
# kept 0000646 / freed 0001398 objects of type HASH
# kept 0000004 / freed 0000121 objects of type BIGNUM
# kept 0000006 / freed 0000005 objects of type FILE
# kept 0000400 / freed 0000253 objects of type DATA
# kept 0000001 / freed 0000093 objects of type MATCH
# kept 0000067 / freed 0000136 objects of type VARMAP
# kept 0000167 / freed 0000939 objects of type SCOPE
# kept 0173634 / freed 0002389 objects of type NODE
# GC time: 47 msec

GCAttributes = [:processed, :live, :freelist, :freed, :time]
GCSummaries  = [:min, :max, :mean, :stddev, :stddev_percentage]

class GCLogEntry
  attr_accessor *GCAttributes
  attr_accessor :live_objects, :freed_objects
  def initialize
    @live_objects = {}
    @freed_objects = {}
  end
end

class GCInfo

  attr_reader(*GCAttributes)
  attr_reader :entries, :num_requests, :collections, :garbage_produced, :time_total, :topology
  attr_reader :live_objects, :freed_objects, :object_types, :garbage_totals

  GCAttributes.each do |attr|
    GCSummaries.each do |method|
      attr_reader "#{attr}_#{method}"
    end
  end

  def initialize(file)
    @entries = []
    @num_requests = 0
    @topology = []
    @object_types = Set.new

    file.each_line do |line|
      case line
      when /^Garbage collection started$/
        @entries << GCLogEntry.new
      when /^objects processed\s*:\s*(\d+)$/
        @entries.last.processed = $1.to_i
      when /^live objects\s*:\s*(\d+)$/
        @entries.last.live = $1.to_i
      when /^freelist objects\s*:\s*(\d+)$/
        @entries.last.freelist = $1.to_i
      when /^freed objects\s*:\s*(\d+)$/
        @entries.last.freed = $1.to_i
      when /^GC time\s*:\s*(\d+)\s*msec$/
        @entries.last.time = $1.to_i
      when /^number of requests processed: (\d+)$/
        @num_requests = $1.to_i
      when /^HEAP\[\s*(\d+)\]: size=\s*(\d+)$/
        @topology << $2.to_i
      when /^kept (\d+) \/ freed (\d+) objects of type ([a-zA-Z]+)/
        @object_types.add($3)
        @entries.last.live_objects[$3] = $1.to_i
        @entries.last.freed_objects[$3] = $2.to_i
      end
    end

    @time_total = @entries.map{|e| e.time}.sum
    @collections = @entries.length
    @garbage_produced = @entries.map{|e| e.freed}.sum
    @live_objects = @entries.map{|e| e.live_objects}
    @freed_objects = @entries.map{|e| e.freed_objects}
    @garbage_totals = @freed_objects.inject(Hash.new(0)) do |totals, freed|
      freed.each do |object_type, count|
        totals[object_type] += freed[object_type] || 0
      end
      totals
    end

    GCAttributes.each do |attr|
      a = @entries.map{|e| e.send attr}
      # we need to pop the last entry, as the freelist is not empty when doing the last forced GC
      a.pop if :freelist == attr.to_sym

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

#    Copyright (C) 2006, 2007, 2008  Stefan Kaes
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
