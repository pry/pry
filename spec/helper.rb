unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Slop v#{Slop::VERSION}"

require 'bacon'
require 'open4'

# Colorize output (based on greeneggs (c) 2009 Michael Fleet)
# TODO: Make own gem (assigned to rking)
module Bacon
  COLORS    = {'F' => 31, 'E' => 35, 'M' => 33, '.' => 32}
  USE_COLOR = !(ENV['NO_PRY_COLORED_BACON'] == 'true') && Pry::Helpers::BaseHelpers.use_ansi_codes?

  module TestUnitOutput
    def handle_requirement(description)
      error = yield

      if error.empty?
        print colorize_string('.')
      else
        print colorize_string(error[0..0])
      end
    end

    def handle_summary
      puts
      puts ErrorLog if Backtraces

      out = "%d tests, %d assertions, %d failures, %d errors" %
        Counter.values_at(:specifications, :requirements, :failed, :errors)

      if Counter.values_at(:failed, :errors).inject(:+) > 0
        puts colorize_string(out, 'F')
      else
        puts colorize_string(out, '.')
      end
    end

    def colorize_string(text, color = nil)
      if USE_COLOR
        "\e[#{ COLORS[color || text] }m#{ text }\e[0m"
      else
        text
      end
    end
  end
end

# Reset toplevel binding at the beginning of each test case.
module Bacon
  class Context
    alias _real_it it
    def it(description, &block)
      Pry.toplevel_binding = nil
      _real_it(description, &block)
    end
  end
end

# A global space for storing temporary state during tests.
Pad = OpenStruct.new
def Pad.clear
  @table = {}
end

# turn warnings off (esp for Pry::Hooks which will generate warnings
# in tests)
$VERBOSE = nil

# inject a variable into a binding
def inject_var(name, value, b)
  Thread.current[:__pry_local__] = value
  b.eval("#{name} = Thread.current[:__pry_local__]")
ensure
  Thread.current[:__pry_local__] = nil
end

def constant_scope(*names)
  names.each do |name|
    Object.remove_const name if Object.const_defined?(name)
  end

  yield
ensure
  names.each do |name|
    Object.remove_const name if Object.const_defined?(name)
  end
end

def mri18_and_no_real_source_location?
  Pry::Helpers::BaseHelpers.mri_18? && !(Method.instance_method(:source_location).owner == Method)
end

# used by test_show_source.rb and test_documentation.rb
class TestClassForShowSource
  def alpha
  end
end

class TestClassForShowSourceClassEval
  def alpha
  end
end

class TestClassForShowSourceInstanceEval
  def alpha
  end
end

# in case the tests call reset_defaults, ensure we reset them to
# amended (test friendly) values
class << Pry
  alias_method :orig_reset_defaults, :reset_defaults
  def reset_defaults
    orig_reset_defaults

    Pry.color = false
    Pry.pager = false
    Pry.config.should_load_rc      = false
    Pry.config.should_load_local_rc= false
    Pry.config.should_load_plugins = false
    Pry.config.history.should_load = false
    Pry.config.history.should_save = false
    Pry.config.auto_indent         = false
    Pry.config.hooks               = Pry::Hooks.new
    Pry.config.collision_warning   = false
  end
end

def mock_exception(*mock_backtrace)
  e = StandardError.new("mock exception")
  (class << e; self; end).class_eval do
    define_method(:backtrace) { mock_backtrace }
  end
  e
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
  args.flatten!
  binding = args.first.is_a?(Binding) ? args.shift : binding()

  input = InputTester.new(*args)
  output = StringIO.new

  redirect_pry_io(input, output) do
    binding.pry
  end

  output.string
end

def mock_command(cmd, args=[], opts={})
  output = StringIO.new
  ret = cmd.new(opts.merge(:output => output)).call_safely(*args)
  Struct.new(:output, :return).new(output.string, ret)
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

class Pry

  # null output class - doesn't write anywwhere.
  class NullOutput
    def self.puts(*) end
    def self.string(*) end
  end
end

# Open a temp file and yield it to the block, closing it after
# @return [String] The path of the temp file
def temp_file(ext='.rb')
  file = Tempfile.new(['pry', ext])
  yield file
ensure
  file.close(true) if file
  File.unlink("#{file.path}c") if File.exists?("#{file.path}c") # rbx
end

def pry_tester(*args, &block)
  if args.length == 0 || args[0].is_a?(Hash)
    args.unshift(Pry.toplevel_binding)
  end

  PryTester.new(*args).tap do |t|
    (class << t; self; end).class_eval(&block) if block
  end
end

def pry_eval(*eval_strs)
  opts = eval_strs.last.is_a?(Hash) ? eval_strs.pop : {}
  if eval_strs.first.is_a? String
    binding = Pry.toplevel_binding
  else
    binding = Pry.binding_for(eval_strs.shift)
  end

  pry_tester(binding, opts).eval(*eval_strs)
end

class PryTester
  attr_reader :pry, :out

  def initialize(context = TOPLEVEL_BINDING, options = {})
    @pry = Pry.new(options)
    @pry.backtrace = options[:backtrace]

    if context
      target = Pry.binding_for(context)
      @pry.binding_stack << target
      @pry.inject_sticky_locals(target)
    end

    @pry.input_array << nil # TODO: shouldn't need this
    reset_output
  end

  def eval(*strs)
    reset_output
    result = nil

    strs.flatten.each do |str|
      str = "#{str.strip}\n"
      if @pry.process_command(str)
        result = last_command_result_or_output
      else
        result = @pry.evaluate_ruby(str)
      end
    end

    result
  end

  def context=(context)
    @pry.binding_stack << Pry.binding_for(context)
  end

  # TODO: eliminate duplication with Pry#repl
  def simulate_repl
    didnt_exit = nil
    break_data = nil

    didnt_exit = catch(:didnt_exit) do
      break_data = catch(:breakout) do
        yield self
        throw(:didnt_exit, true)
      end
      nil
    end

    raise "Failed to exit REPL" if didnt_exit
    break_data
  end

  def last_output
    @out.string if @out
  end

  def process_command(command_str, eval_str = '')
    @pry.process_command(command_str, eval_str) or raise "Not a valid command"
    last_command_result_or_output
  end

  protected

  def last_command_result
    result = Thread.current[:__pry_cmd_result__]
    result.retval if result
  end

  def last_command_result_or_output
    result = last_command_result
    if result != Pry::Command::VOID_VALUE
      result
    else
      last_output
    end
  end

  def reset_output
    @out = StringIO.new
    @pry.output = @out
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

def unindent(*args)
  Pry::Helpers::CommandHelpers.unindent(*args)
end

# to help with tracking down bugs that cause an infinite loop in the test suite
if ENV["SET_TRACE_FUNC"]
  require 'set_trace' if Pry::Helpers::BaseHelpers.rbx?
  set_trace_func proc { |event, file, line, id, binding, classname|
     STDERR.printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
  }
end
