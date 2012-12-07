unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/pry/test/helper')

class Module
  public :remove_const
  public :remove_method
end

# turn warnings off (esp for Pry::Hooks which will generate warnings
# in tests)
$VERBOSE = nil

# Set I/O streams.
#
# Out defaults to an anonymous StringIO.
def redirect_pry_io(new_in, new_out = StringIO.new)
  old_in = Pry.input
  old_out = Pry.output

  Pry.input = new_in
  Pry.output = new_out
  begin
    yield
  ensure
    Pry.input = old_in
    Pry.output = old_out
  end
end

class InputTester
  def initialize(*actions)
    @orig_actions = actions.dup
    @actions = actions
  end

  def readline(*)
    @actions.shift
  end

  def rewind
    @actions = @orig_actions.dup
  end
end

# to help with tracking down bugs that cause an infinite loop in the test suite
if ENV["SET_TRACE_FUNC"]
  require 'set_trace' if Pry::Helpers::BaseHelpers.rbx?
  set_trace_func proc { |event, file, line, id, binding, classname|
     STDERR.printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  }
end
