# @author John Mair (banisterfiend)
class Pry

  # The RC Files to load. 
  RC_FILES = ["~/.pryrc"]
  
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

    # Get last exception raised.
    # This method should not need to be accessed directly.
    # @return [Exception] The last exception.
    attr_accessor :last_exception

    # Get the active Pry instance that manages the active Pry session.
    # This method should not need to be accessed directly.
    # @return [Pry] The active Pry instance.
    attr_accessor :active_instance

    # Get/Set the object to use for input by default by all Pry instances.
    # @return [#readline] The object to use for input by default by all
    #   Pry instances.
    attr_accessor :input

    # Get/Set the object to use for output by default by all Pry instances.
    # @return [#puts] The object to use for output by default by all
    #   Pry instances.
    attr_accessor :output

    # Get/Set the object to use for commands by default by all Pry instances.
    # @return [Pry::CommandBase] The object to use for commands by default by all
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

    
    # Get/Set the Proc that defines extra Readline completions (on top
    # of the ones defined for IRB).
    # @return [Proc] The Proc that defines extra Readline completions (on top
    # @example Add file names to completion list
    #   Pry.custom_completions = proc { Dir.entries('.') }
    attr_accessor :custom_completions

    # Get the array of Procs to be used for the prompts by default by
    # all Pry instances.
    # @return [Array<Proc>] The array of Procs to be used for the
    #   prompts by default by all Pry instances.
    attr_accessor :prompt

    # Value returned by last executed Pry command.
    # @return [Object] The command value
    attr_accessor :cmd_ret_value

    # Determines whether colored output is enabled.
    # @return [Boolean] 
    attr_accessor :color

    # Determines whether the rc file (~/.pryrc) should be loaded.
    # @return [Boolean] 
    attr_accessor :should_load_rc

    # Set to true if Pry is invoked from command line using `pry` executable
    # @return [Boolean]
    attr_accessor :cli

    # Set to true if the pry-doc extension is loaded.
    # @return [Boolean]
    attr_accessor :has_pry_doc
  end

  # Load the rc files given in the `Pry::RC_FILES` array.
  # Defaults to loading just `~/.pryrc`. This method can also
  # be used to reload the files if they have changed.
  def self.load_rc
    RC_FILES.each do |file_name|
      file_name = File.expand_path(file_name)
      load(file_name) if File.exists?(file_name)
    end
  end
  
  # Start a Pry REPL.
  # This method also loads the files specified in `Pry::RC_FILES` the
  # first time it is invoked.
  # @param [Object, Binding] target The receiver of the Pry session
  # @param [Hash] options
  # @option options (see Pry#initialize)
  # @example
  #   Pry.start(Object.new, :input => MyInput.new)
  def self.start(target=TOPLEVEL_BINDING, options={})
    if should_load_rc && !@rc_loaded
      load_rc
      @rc_loaded = true
    end
    
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

  rescue NoMethodError
    "unknown"
  end

  # A version of `Pry.view` that clips the output to `max_size` chars.
  # In case of > `max_size` chars the `#<Object...> notation is used.
  # @param obj The object to view.
  # @param max_size The maximum number of chars before clipping occurs.
  # @return [String] The string representation of `obj`.
  def self.view_clip(obj, max_size=60)
    if Pry.view(obj).size < max_size
      Pry.view(obj)
    else
      "#<#{obj.class}:%#x>" % (obj.object_id << 1)
    end
  end

  # Run a Pry command from outside a session. The commands available are
  # those referenced by `Pry.commands` (the default command set).
  # Command output is suppresed by default, this is because the return
  # value (if there is one) is likely to be more useful.
  # @param [String] arg_string The Pry command (including arguments,
  #   if any).
  # @param [Hash] options Optional named parameters.
  # @return [Object] The return value of the Pry command.
  # @option options [Object, Binding] :context The object context to run the
  #   command under. Defaults to `TOPLEVEL_BINDING` (main).
  # @option options [Boolean] :show_output Whether to show command
  #   output. Defaults to false.
  # @example Run at top-level with no output.
  #   Pry.run_command "ls"
  # @example Run under Pry class, returning only public methods.
  #   Pry.run_command "ls -m", :context => Pry
  # @example Display command output.
  #   Pry.run_command "ls -av", :show_output => true
  def self.run_command(arg_string, options={})
    name, arg_string = arg_string.split(/\s+/, 2)
    arg_string = "" if !arg_string
    
    options = {
      :context => TOPLEVEL_BINDING,
      :show_output => false,
      :output => Pry.output,
      :commands => Pry.commands
    }.merge!(options)
    
    null_output = Object.new.tap { |v| v.instance_eval { def puts(*) end } }
    
    commands = options[:commands].clone
    commands.output = options[:show_output] ? options[:output] : null_output
    commands.target = Pry.binding_for(options[:context])

    cmd = commands.commands[name]
    if cmd
      action = cmd[:action]
      commands.instance_exec(*Shellwords.shellwords(arg_string), &action)
    else
      raise "No such Pry command: #{name}"
    end
  end

  # Set all the configurable options back to their default values
  def self.reset_defaults
    @input = Readline
    @output = $stdout
    @commands = Pry::Commands
    @prompt = DEFAULT_PROMPT
    @print = DEFAULT_PRINT
    @hooks = DEFAULT_HOOKS
    @custom_completions = DEFAULT_CUSTOM_COMPLETIONS
    @color = true
    @should_load_rc = true
    @rc_loaded = false
    @cli = false
  end

  self.reset_defaults

  @nesting = []
  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end

  # Return all active Pry sessions.
  # @return [Array<Pry>] Active Pry sessions.
  def self.sessions
    # last element in nesting array is the pry instance
    nesting.map(&:last)
  end

  # Return a `Binding` object for `target` or return `target` if it is
  # already a `Binding`.
  # In the case where `target` is top-level then return `TOPLEVEL_BINDING`
  # @param [Object] target The object to get a `Binding` object for.
  # @return [Binding] The `Binding` object.
  def self.binding_for(target)
    if target.is_a?(Binding)
      target
    else
      if target == TOPLEVEL_BINDING.eval('self')
        TOPLEVEL_BINDING
      else
        target.__binding__
      end
    end
  end
end
