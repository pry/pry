class Object
  def test_method
  end
end

class InputTester
  def initialize(actions)
    @orig_actions = Array(actions.dup)
    @actions = Array(actions)
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
    puts val.inspect
  end

  def method_missing(meth_name, *args, &block)
    define_singleton_method("#{meth_name}_invoked") { true }
  end
end
    
    
