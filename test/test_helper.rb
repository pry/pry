class Object
  def test_method
  end
end

class InputTester
  def initialize(*actions)
    @orig_actions = actions.dup
    @actions = actions
  end

  def read(*)
    @actions.shift
  end

  def rewind
    @actions = @orig_actions
  end
end

class OutputTester
  attr_reader :output_buffer

  def initialize
    @output_buffer = ""
  end

  def print(val)
    @output_buffer = val
  end

  def method_missing(meth_name, *args, &block)
    class << self; self; end.send(:define_method, "#{meth_name}_invoked") { true }
  end
end
    
    
