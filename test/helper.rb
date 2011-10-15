unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}"

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
    Pry.config.should_load_rc      = false
    Pry.config.plugins.enabled     = false
    Pry.config.history.should_load = false
    Pry.config.history.should_save = false
    Pry.config.auto_indent         = false
    Pry.config.hooks = { }
  end
end

class MockPryException
  attr_accessor :bt_index
  attr_accessor :backtrace

  def initialize(*backtrace)
    @backtrace = backtrace
    @bt_index = 0
  end

  def message
    "mock exception"
  end

  def bt_source_location_for(index)
    backtrace[index] =~ /(.*):(\d+)/
    [$1, $2.to_i]
  end
end

# are we on Jruby platform?
def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /jruby/
end

# are we on rbx platform?
def rbx?
  defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/
end

Pry.reset_defaults

# this is to test exception code (cat --ex)
def broken_method
  this method is broken
end

# sample doc
def sample_method
  :sample
end

# another sample doc
def another_sample_method
  :another_sample
end

# Set I/O streams.
#
# Out defaults to an anonymous StringIO.
#
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

def mock_pry(*args)

  binding = args.first.is_a?(Binding) ? args.shift : binding()

  input = InputTester.new(*args)
  output = StringIO.new

  redirect_pry_io(input, output) do
    binding.pry
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

# Open a temp file and yield it to the block, closing it after
# @return [String] The path of the temp file
def temp_file
  file = Tempfile.new("tmp")
  yield file
ensure
  file.close
end


CommandTester = Pry::CommandSet.new do
  command "command1", "command 1 test" do
    output.puts "command1"
  end

  command "command2", "command 2 test" do |arg|
    output.puts arg
  end
end
