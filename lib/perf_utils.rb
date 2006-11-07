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
