class Hash
  
  def except(*keys)
    self.reject {|k,v| keys.include?(k || k.to_sym)}
  end
  
  def only(*keys)
    self.reject {|k,v| !keys.include?(k || k.to_sym)}
  end
  
  def with(overides={})
    self.merge(overides)
  end

  def has_keys?(*keys)
    keys.each do |key|
      return false unless has_key?(key)
    end
    return true
  end

end
