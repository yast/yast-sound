# add to_ycp method for conveting the objects to YCP string notation
# these definition extend the basic Ruby classes

# the indent parameter is used for nice indented output
# it's used recursively for indenting nested structures

class Array
  def to_ycp(indent = 0)
    ret = ''

    self.each do |x|
      ret += ",\n" unless ret.empty?
      ret += ('  ' * (indent + 1)) + x.to_ycp(indent + 1)
    end

    return "[\n#{ret}\n#{'  ' * (indent)}]"
  end
end

class String
  def to_ycp(indent = 0)
    "\"#{self}\""
  end
end

class Fixnum
  def to_ycp(indent = 0)
    self.to_s
  end
end

class Bignum
  def to_ycp(indent = 0)
    self.to_s
  end
end

class Hash
  def to_ycp(indent = 0)
    ret = ''
    k = self.keys.sort

    k.each do |key|
      ret += ",\n" unless ret.empty?
      ret += ('  ' * (indent + 1)) + "#{key.to_ycp(indent + 1)} : #{self[key].to_ycp(indent + 1)}"
    end

    return "$[\n#{ret}\n#{'  ' * (indent)}]"
  end
end

