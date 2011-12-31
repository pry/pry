class Pry
  # Command contexts are the objects runing each command.
  # Helper modules can be mixed into this class.
  class Command

    # represents a void return value for a command
    VOID_VALUE = Object.new

    # give it a nice inspect
    def VOID_VALUE.inspect() "void" end

    class << self
      attr_accessor :name
      attr_accessor :description
      attr_accessor :options
      attr_accessor :block
    end

    attr_accessor :command_name
    attr_accessor :output
    attr_accessor :target
    attr_accessor :target_self
    attr_accessor :captures
    attr_accessor :eval_string
    attr_accessor :arg_string
    attr_accessor :opts
    attr_accessor :command_set
    attr_accessor :command_processor
    attr_accessor :_pry_

    def initialize(&block)
      instance_exec(&block) if block
    end

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
      command_processor.process_commands(complete_string, eval_string, target)
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


    attr_accessor :context

    %w(name description options block).each do |attribute|
      define_method(attribute) { self.class.send(attribute) }
    end

    class << self
      def inspect
        "#<class(Pry command #{name.inspect})>"
      end

      def subclass(name, description, options, helpers, &block)
        klass = Class.new(self)
        klass.send(:include, helpers)
        klass.name = name
        klass.description = description
        klass.options = options
        klass.block = block
        klass
      end

      def hooks
        @hooks ||= {:before => [], :after => []}
      end
    end

    def initialize(context)
      self.context      = context
      self.target       = context[:target]
      self.target_self  = context[:target].eval('self')
      self.output       = context[:output]
      self.captures     = context[:captures]
      self.eval_string  = context[:eval_string]
      self.arg_string   = context[:arg_string]
      self.command_set  = context[:command_set]
      self.command_name = self.class.options[:listing]
      self._pry_        = context[:pry_instance]
      self.command_processor = context[:command_processor]
    end

    def call_safely(*args)
      if dependencies_met?
        call_with_hooks(*args)
      else
        gems_needed = Array(command_options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }
        output.puts "\nThe command '#{name}' is #{Helpers::Text.bold("unavailable")} because it requires the following gems to be installed: #{(gems_not_installed.join(", "))}"
        output.puts "-"
        output.puts "Type `install-command #{name}` to install the required gems and activate this command."
      end
    end

    def call_with_hooks(*args)
      self.class.hooks[:before].each do |block|
        instance_exec(*args, &block)
      end

      ret = call *args

      self.class.hooks[:after].each do |block|
        ret = instance_exec(*args, &block)
      end

      command_options[:keep_retval] ? ret : void
    end

    def command_options; self.class.options; end

    def dependencies_met?
      @dependencies_met ||= command_dependencies_met?(command_options)
    end
  end

  class BlockCommand < Command
    # backwards compatibility
    alias_method :opts, :context

    def call(*args)
      if options[:argument_required] && args.empty?
        raise CommandError, "The command '#{command.name}' requires an argument."
      end

      instance_exec(*correct_arg_arity(block.arity, args), &block)
    end

    private
    def correct_arg_arity(arity, args)
      case
      when arity < 0
        args
      when arity == 0
        []
      when arity > 0
        args.values_at *(0..(arity - 1)).to_a
      end
    end
  end

  class ClassCommand < Command
    attr_accessor :opts
    attr_accessor :args

    def call(*args)
      setup

      self.opts = slop
      self.args = self.opts.parse!(args)

      if opts.present?(:help)
        output.puts slop.help
      else
        run
      end
    end

    def setup; end
    def options(opt); end
    def run; raise CommandError, "command '#{name}' not implemented" end

    def slop
      Slop.new do |opt|
        options(opt)
        opt.on(:h, :help, "Show this message.")
      end
    end
  end
end
