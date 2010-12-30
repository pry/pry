# @author John Mair (banisterfiend)
class Pry

  # class accessors
  class << self

    # Get nesting data.
    # This method should not need to be accessed directly.
    # @return [Array] The unparsed nesting information.
    attr_reader :nesting

    # Get last value evaluated by Pry.
    # This method should not need to be accessed directly.
    # @return [Object] The last result.
    attr_accessor :last_result

    # Get the active Pry instance that manages the active Pry session.
    # This method should not need to be accessed directly.
    # @return [Pry] The active Pry instance.
    attr_accessor :active_instance
    
    # Get/Set the object to use for input by default by all Pry instances.
    # @return [#read] The object to use for input by default by all
    #   Pry instances.
    attr_accessor :input

    # Get/Set the object to use for output by default by all Pry instances.
    # @return [#puts] The object to use for output by default by all
    #   Pry instances.
    attr_accessor :output

    # Get/Set the object to use for commands by default by all Pry instances.
    # @return [#commands] The object to use for commands by default by all
    #   Pry instances.
    attr_accessor :commands

    # Get/Set the Proc to use for printing by default by all Pry
    # instances.
    # This is the 'print' component of the REPL.
    # @return [Proc] The Proc to use for printing by default by all
    #   Pry instances.
    attr_accessor :print

    
    # Get/Set the Hash that defines Pry hooks used by default by all Pry
    # instances.
    # @return [Hash] The hooks used by default by all Pry instances.
    # @example
    #   Pry.hooks :before_session => proc { puts "hello" },
    #     :after_session => proc { puts "goodbye" }
    attr_accessor :hooks

    # Get/Set the array of Procs to be used for the prompts by default by
    # all Pry instances.
    # @return [Array<Proc>] The array of Procs to be used for the
    #   prompts by default by all Pry instances.
    attr_accessor :default_prompt
  end

  # Start a Pry REPL.
  # @param [Object, Binding] target The receiver of the Pry session
  # @param [Hash] options
  # @option options (see Pry#initialize)
  # @example
  #   Pry.start(Object.new, :input => MyInput.new)
  def self.start(target=TOPLEVEL_BINDING, options={})
    new(options).repl(target)
  end

  # A custom version of `Kernel#inspect`.
  # This method should not need to be accessed directly.
  # @param obj The object to view.
  # @return [String] The string representation of `obj`.
  def self.view(obj)
    case obj
    when String, Hash, Array, Symbol, nil
      obj.inspect
    else
      obj.to_s
    end
  end

  # Set all the configurable options back to their default values
  def self.reset_defaults
    @input = Input.new
    @output = Output.new
    @commands = Commands.new(@output)
    @default_prompt = STANDARD_PROMPT
    @print = DEFAULT_PRINT
    @hooks = DEFAULT_HOOKS
  end

  self.reset_defaults

  @nesting = []
  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end
end
