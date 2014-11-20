class Object
  def pajama_deep_freeze
    freeze
  end
end

class Array
  def pajama_deep_freeze
    each(&:pajama_deep_freeze)
    freeze
  end
end

class Hash
  def pajama_deep_freeze
    keys.pajama_deep_freeze
    values.pajama_deep_freeze
    freeze
  end
end
