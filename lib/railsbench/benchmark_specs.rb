require 'delegate'
require 'yaml'
require 'erb'

class BenchmarkSpec < DelegateClass(Hash)
  attr_accessor :name

  READERS = %w(uri method post_data query_string new_session action controller session_data xhr raw_data)
  READERS.each do |method|
    define_method(method) { self[method] }
  end

  def initialize(name, hash)
    super(hash)
    @name = name
  end

  def inspect
    "BenchmarkSpec(#{name},#{super})"
  end

  class << self
    def load(name, file_name = nil)
      unless file_name
        file_name = ENV['RAILS_ROOT'] + "/config/benchmarks.yml"
      end
      @@specs = YAML::load(ERB.new(IO.read(file_name)).result)
      raise "There is no benchmark named '#{name}'" unless @@specs[name]
      parse(@@specs, name)
    end

    def parse(specs, name)
      spec = specs[name]
      if spec.is_a?(String)
        spec.split(/, */).collect!{ |n| parse(specs, n) }.flatten
      elsif spec.is_a?(Hash)
        [ BenchmarkSpec.new(name,spec) ]
      elsif spec.is_a?(Array)
        spec.collect{|n| parse(specs, n)}.flatten
      else
        raise "oops: unknown entry type in benchmark specification"
      end
    end
  end
end

__END__

#  Copyright (C) 2007, 2008  Stefan Kaes
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
