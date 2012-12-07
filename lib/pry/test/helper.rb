require 'pry'

puts "Ruby v#{RUBY_VERSION} (#{defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby"}), Pry v#{Pry::VERSION}, method_source v#{MethodSource::VERSION}, CodeRay v#{CodeRay::VERSION}, Slop v#{Slop::VERSION}"

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
Pry.reset_defaults

# A global space for storing temporary state during tests.
Pad = OpenStruct.new
def Pad.clear
  @table = {}
end

module PryTestHelpers

  module_function

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

  # Open a temp file and yield it to the block, closing it after
  # @return [String] The path of the temp file
  def temp_file(ext='.rb')
    file = Tempfile.new(['pry', ext])
    yield file
  ensure
    file.close(true) if file
    File.unlink("#{file.path}c") if File.exists?("#{file.path}c") # rbx
  end

  def unindent(*args)
    Pry::Helpers::CommandHelpers.unindent(*args)
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

def mock_exception(*mock_backtrace)
  e = StandardError.new("mock exception")
  (class << e; self; end).class_eval do
    define_method(:backtrace) { mock_backtrace }
  end
  e
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
  if eval_strs.first.is_a? String
    binding = Pry.toplevel_binding
  else
    binding = Pry.binding_for(eval_strs.shift)
  end

  pry_tester(binding).eval(*eval_strs)
end

class PryTester
  attr_reader :pry, :out

  def initialize(context = TOPLEVEL_BINDING, options = {})
    @pry = Pry.new(options)

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

if defined?(Bacon)
  require File.join(File.expand_path(File.dirname(__FILE__)), 'bacon_helper')
end
