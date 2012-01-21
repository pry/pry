class Pry

  # The super-class of all commands, new commands should be created by calling
  # {Pry::CommandSet#command} which creates a BlockCommand or {Pry::CommandSet#create_command}
  # which creates a ClassCommand. Please don't use this class directly.
  class Command

    # represents a void return value for a command
    VOID_VALUE = Object.new

    # give it a nice inspect
    def VOID_VALUE.inspect() "void" end

    # Properties of the command itself (as passed as arguments to
    # {CommandSet#command} or {CommandSet#create_command}).
    class << self
      attr_accessor :block
      attr_accessor :name
      attr_writer :description
      attr_writer :command_options

      # Define or get the command's description
      def description(arg=nil)
        @description = arg if arg
        @description
      end

      # Define or get the command's options
      def command_options(arg=nil)
        @command_options ||= {}
        @command_options.merge!(arg) if arg
        @command_options
      end
      # backward compatibility
      alias_method :options, :command_options
      alias_method :options=, :command_options=

      # Define or get the command's banner
      def banner(arg=nil)
        @banner = arg if arg
        @banner || description
      end
    end


    # Make those properties accessible to instances
    def name; self.class.name; end
    def description; self.class.description; end
    def block; self.class.block; end
    def command_options; self.class.options; end
    def command_name; command_options[:listing]; end

    class << self
      def inspect
        "#<class(Pry::Command #{name.inspect})>"
      end

      # Create a new command with the given properties.
      #
      # @param String name  the name of the command
      # @param String description  the description to appear in {help}
      # @param Hash options  behavioural options (@see {Pry::CommandSet#command})
      # @param Module helpers  a module of helper functions to be included.
      # @param Proc &block  (optional, a block, used for BlockCommands)
      #
      # @return Class (a subclass of Pry::Command)
      #
      def subclass(name, description, options, helpers, &block)
        klass = Class.new(self)
        klass.send(:include, helpers)
        klass.name = name
        klass.description = description
        klass.command_options = options
        klass.block = block
        klass
      end

      # Should this command be called for the given line?
      #
      # @param String  a line input at the REPL
      # @return Boolean
      def matches?(val)
        command_regex =~ val
      end

      # Store hooks to be run before or after the command body.
      # @see {Pry::CommandSet#before_command}
      # @see {Pry::CommandSet#after_command}
      def hooks
        @hooks ||= {:before => [], :after => []}
      end

      def command_regex
        prefix = convert_to_regex(Pry.config.command_prefix)
        prefix = "(?:#{prefix})?" unless options[:use_prefix]

        /^#{prefix}#{convert_to_regex(name)}(?!\S)/
      end

      def convert_to_regex(obj)
        case obj
        when String
          Regexp.escape(obj)
        else
          obj
        end
      end
    end


    # Properties of one execution of a command (passed by {Pry#run_command} as a hash of
    # context and expanded in {#initialize}
    attr_accessor :output
    attr_accessor :target
    attr_accessor :captures
    attr_accessor :eval_string
    attr_accessor :arg_string
    attr_accessor :context
    attr_accessor :command_set
    attr_accessor :_pry_

    # Run a command from another command.
    # @param [String] command_string The string that invokes the command
    # @param [Array] args Further arguments to pass to the command
    # @example
    #   run "show-input"
    # @example
    #   run ".ls"
    # @example
    #   run "amend-line",  "5", 'puts "hello world"'
    def run(command_string, *args)
      complete_string = "#{command_string} #{args.join(" ")}"
      command_set.process_line(complete_string, context)
    end

    def commands
      command_set.commands
    end

    def text
      Pry::Helpers::Text
    end

    def void
      VOID_VALUE
    end

    include Pry::Helpers::BaseHelpers
    include Pry::Helpers::CommandHelpers


    # Instantiate a command, in preparation for calling it.
    #
    # @param Hash context  The runtime context to use with this command.
    def initialize(context={})
      self.context      = context
      self.target       = context[:target]
      self.output       = context[:output]
      self.eval_string  = context[:eval_string]
      self.command_set  = context[:command_set]
      self._pry_        = context[:pry_instance]
    end

    # The value of {self} inside the {target} binding.
    def target_self; target.eval('self'); end

    # Revaluate the string (str) and perform interpolation.
    # @param [String] str The string to reevaluate with interpolation.
    #
    # @return [String] The reevaluated string with interpolations
    #   applied (if any).
    def interpolate_string(str)
      dumped_str = str.dump
      if dumped_str.gsub!(/\\\#\{/, '#{')
        target.eval(dumped_str)
      else
        str
      end
    end

    # Display a warning if a command collides with a local/method in
    # the current scope.
    # @param [String] command_name_match The name of the colliding command.
    # @param [Binding] target The current binding context.
    def check_for_command_name_collision(command_name_match)
      if collision_type = target.eval("defined?(#{command_name_match})")
        output.puts "#{Pry::Helpers::Text.bold('WARNING:')} Command name collision with a #{collision_type}: '#{command_name_match}'\n\n"
      end
    rescue Pry::RescuableException
    end

    # Extract necessary information from a line that Command.matches? this command.
    #
    # @param String  the line of input
    # @return [
    #   String   the command name used, or portion of line that matched the command_regex
    #   String   a string of all the arguments (i.e. everything but the name)
    #   Array    the captures caught by the command_regex
    #   Array    args the arguments got by splitting the arg_string
    # ]
    def tokenize(val)
      val.replace(interpolate_string(val)) if command_options[:interpolate]

      self.class.command_regex =~ val

      # please call Command.matches? before Command#call_safely
      raise CommandError, "fatal: called a command which didn't match?!" unless Regexp.last_match
      captures = Regexp.last_match.captures
      pos = Regexp.last_match.end(0)

      arg_string = val[pos..-1]

      # remove the one leading space if it exists
      arg_string.slice!(0) if arg_string.start_with?(" ")

      if arg_string
        args = command_options[:shellwords] ? Shellwords.shellwords(arg_string) : arg_string.split(" ")
      else
        args = []
      end

      [val[0..pos].rstrip, arg_string, captures, args]
    end

    # Process a line that Command.matches? this command.
    #
    # @param String  the line to process
    # @return  Object or Command::VOID_VALUE
    def process_line(line)
      command_name, arg_string, captures, args = tokenize(line)

      check_for_command_name_collision(command_name) if Pry.config.collision_warning

      self.arg_string = arg_string
      self.captures = captures

      call_safely(*(captures + args))
    end

    # Run the command with the given {args}.
    #
    # This is a public wrapper around {#call} which ensures all preconditions are met.
    #
    # @param *[String]  the arguments to pass to this command.
    # @return Object  the return value of the {#call} method, or Command::VOID_VALUE
    def call_safely(*args)
      unless dependencies_met?
        gems_needed = Array(command_options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }
        output.puts "\nThe command '#{name}' is #{Helpers::Text.bold("unavailable")} because it requires the following gems to be installed: #{(gems_not_installed.join(", "))}"
        output.puts "-"
        output.puts "Type `install-command #{name}` to install the required gems and activate this command."
        return void
      end

      if command_options[:argument_required] && args.empty?
        raise CommandError, "The command '#{name}' requires an argument."
      end

      ret = call_with_hooks(*args)
      command_options[:keep_retval] ? ret : void
    end

    # Are all the gems required to use this command installed?
    #
    # @return  Boolean
    def dependencies_met?
      @dependencies_met ||= command_dependencies_met?(command_options)
    end

    private

    # Run the {#call} method and all the registered hooks.
    #
    # @param *String  the arguments to #{call}
    # @return Object  the return value from #{call}
    def call_with_hooks(*args)
      self.class.hooks[:before].each do |block|
        instance_exec(*args, &block)
      end

      ret = call(*args)

      self.class.hooks[:after].each do |block|
        ret = instance_exec(*args, &block)
      end

      ret
    end

    # Fix the number of arguments we pass to a block to avoid arity warnings.
    #
    # @param Number  the arity of the block
    # @param Array   the arguments to pass
    # @return Array  a (possibly shorter) array of the arguments to pass
    def correct_arg_arity(arity, args)
      case
      when arity < 0
        args
      when arity == 0
        []
      when arity > 0
        args.values_at(*(0..(arity - 1)).to_a)
      end
    end
  end

  # A super-class for Commands that are created with a single block.
  #
  # This class ensures that the block is called with the correct number of arguments
  # and the right context.
  #
  # Create subclasses using {Pry::CommandSet#command}.
  class BlockCommand < Command
    # backwards compatibility
    alias_method :opts, :context

    # Call the block that was registered with this command.
    #
    # @param *String  the arguments passed
    # @return Object  the return value of the block
    def call(*args)
      instance_exec(*correct_arg_arity(block.arity, args), &block)
    end

    def help; description; end
  end

  # A super-class ofr Commands with structure.
  #
  # This class implements the bare-minimum functionality that a command should have,
  # namely a --help switch, and then delegates actual processing to its subclasses.
  #
  # Create subclasses using {Pry::CommandSet#create_command}, and override the {options(opt)} method
  # to set up an instance of Slop, and the {process} method to actually run the command. If
  # necessary, you can also override {setup} which will be called before {options}, for example to
  # require any gems your command needs to run, or to set up state.
  class ClassCommand < Command

    attr_accessor :opts
    attr_accessor :args

    # Set up {opts} and {args}, and then call {process}
    #
    # This function will display help if necessary.
    #
    # @param *String  the arguments passed
    # @return Object  the return value of {process} or VOID_VALUE
    def call(*args)
      setup

      self.opts = slop
      self.args = self.opts.parse!(args)

      if opts.present?(:help)
        output.puts slop.help
        void
      else
        process(*correct_arg_arity(method(:process).arity, args))
      end
    end

    # Return the help generated by Slop for this command.
    def help
      slop.help
    end

    # Return an instance of Slop that can parse the options that this command accepts.
    def slop
      Slop.new do |opt|
        opt.banner(unindent(self.class.banner))
        options(opt)
        opt.on(:h, :help, "Show this message.")
      end
    end

    # A function called just before {options(opt)} as part of {call}.
    #
    # This function can be used to set up any context your command needs to run, for example
    # requiring gems, or setting default values for options.
    #
    # @example
    #   def setup;
    #     require 'gist'
    #     @action = :method
    #   end
    def setup; end

    # A function to setup Slop so it can parse the options your command expects.
    #
    # NOTE: please don't do anything side-effecty in the main part of this method,
    # as it may be called by Pry at any time for introspection reasons. If you need
    # to set up default values, use {setup} instead.
    #
    # @example
    #  def options(opt)
    #    opt.banner "Gists methods or classes"
    #    opt.on(:c, :class, "gist a class") do
    #      @action = :class
    #    end
    #  end
    def options(opt); end

    # The actual body of your command should go here.
    #
    # The {opts} mehod can be called to get the options that Slop has passed,
    # and {args} gives the remaining, unparsed arguments.
    #
    # The return value of this method is discarded unless the command was created
    # with :keep_retval => true, in which case it is returned to the repl.
    #
    # @example
    #   def process
    #     if opts.present?(:class)
    #       gist_class
    #     else
    #       gist_method
    #     end
    #   end
    def process; raise CommandError, "command '#{name}' not implemented" end
  end
end
