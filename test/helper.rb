unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

require 'bacon'
require 'open4'

# Ensure we do not execute any rc files
Pry::RC_FILES.clear

# in case the tests call reset_defaults, ensure we reset them to
# amended (test friendly) values
class << Pry
  alias_method :orig_reset_defaults, :reset_defaults
  def reset_defaults
    orig_reset_defaults

    Pry.color = false
    Pry.pager = false
    Pry.config.should_load_rc = false
    Pry.config.plugins.enabled = false
    Pry.config.history.should_load = false
    Pry.config.history.should_save = false
  end
end

Pry.reset_defaults

# sample doc
def sample_method
  :sample
end

# another sample doc
def another_sample_method
  :another_sample
end

def redirect_pry_io(new_in, new_out)
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

def mock_pry(*args)
  input = InputTester.new(*args)
  output = StringIO.new

  redirect_pry_io(input, output) do
    Pry.start
  end

  output.string
end

def redirect_global_pry_input(new_io)
  old_io = Pry.input
    Pry.input = new_io
    begin
      yield
    ensure
      Pry.input = old_io
    end
end

def redirect_global_pry_output(new_io)
  old_io = Pry.output
    Pry.output = new_io
    begin
      yield
    ensure
      Pry.output = old_io
    end
end

class Module
  public :remove_const
  public :remove_method
end


class InputTester
  def initialize(*actions)
    if actions.last.is_a?(Hash) && actions.last.keys == [:history]
      @hist = actions.pop[:history]
    end
    @orig_actions = actions.dup
    @actions = actions
  end

  def readline(*)
    @actions.shift.tap{ |line| @hist << line if @hist }
  end

  def rewind
    @actions = @orig_actions.dup
  end
end

class Pry

  # null output class - doesn't write anywwhere.
  class NullOutput
    def self.puts(*) end
    def self.string(*) end
  end
end


CommandTester = Pry::CommandSet.new do
  command "command1", "command 1 test" do
    output.puts "command1"
  end

  command "command2", "command 2 test" do |arg|
    output.puts arg
  end
end
