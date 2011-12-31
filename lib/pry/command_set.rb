require 'pry/command_context'
class Pry
  class NoCommandError < StandardError
    def initialize(name, owner)
      super "Command '#{name}' not found in command set #{owner}"
    end
  end

  # This class is used to create sets of commands. Commands can be imported from
  # different sets, aliased, removed, etc.
  class CommandSet
    class Command < Pry::CommandContext

      class << self
        attr_accessor :name
        attr_accessor :description
        attr_accessor :options
        attr_accessor :block
      end

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

        command_options[:keep_retval] ? ret : CommandContext::VOID_VALUE
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

    include Enumerable
    include Pry::Helpers::BaseHelpers

    attr_reader :commands
    attr_reader :helper_module

    # @param [Array<CommandSet>] imported_sets Sets which will be imported
    #   automatically
    # @yield Optional block run to define commands
    def initialize(*imported_sets, &block)
      @commands      = {}
      @helper_module = Module.new

      define_default_commands
      import(*imported_sets)

      instance_eval(&block) if block
    end

    # Defines a new Pry command.
    # @param [String, Regexp] name The name of the command. Can be
    #   Regexp as well as String.
    # @param [String] description A description of the command.
    # @param [Hash] options The optional configuration parameters.
    # @option options [Boolean] :keep_retval Whether or not to use return value
    #   of the block for return of `command` or just to return `nil`
    #   (the default).
    # @option options [Array<String>] :requires_gem Whether the command has
    #   any gem dependencies, if it does and dependencies not met then
    #   command is disabled and a stub proc giving instructions to
    #   install command is provided.
    # @option options [Boolean] :interpolate Whether string #{} based
    #   interpolation is applied to the command arguments before
    #   executing the command. Defaults to true.
    # @option options [String] :listing The listing name of the
    #   command. That is the name by which the command is looked up by
    #   help and by show-command. Necessary for regex based commands.
    # @option options [Boolean] :use_prefix Whether the command uses
    #   `Pry.config.command_prefix` prefix (if one is defined). Defaults
    #   to true.
    # @option options [Boolean] :shellwords Whether the command's arguments
    #   should be split using Shellwords instead of just split on spaces.
    #   Defaults to true.
    # @yield The action to perform. The parameters in the block
    #   determines the parameters the command will receive. All
    #   parameters passed into the block will be strings. Successive
    #   command parameters are separated by whitespace at the Pry prompt.
    # @example
    #   MyCommands = Pry::CommandSet.new do
    #     command "greet", "Greet somebody" do |name|
    #       puts "Good afternoon #{name.capitalize}!"
    #     end
    #   end
    #
    #   # From pry:
    #   # pry(main)> _pry_.commands = MyCommands
    #   # pry(main)> greet john
    #   # Good afternoon John!
    #   # pry(main)> help greet
    #   # Greet somebody
    # @example Regexp command
    #   MyCommands = Pry::CommandSet.new do
    #     command /number-(\d+)/, "number-N regex command", :listing => "number" do |num, name|
    #       puts "hello #{name}, nice number: #{num}"
    #     end
    #   end
    #
    #   # From pry:
    #   # pry(main)> _pry_.commands = MyCommands
    #   # pry(main)> number-10 john
    #   # hello john, nice number: 10
    #   # pry(main)> help number
    #   # number-N regex command
    def command(name, description="No description.", options={}, &block)
      options = {
        :requires_gem => [],
        :keep_retval => false,
        :argument_required => false,
        :interpolate => true,
        :shellwords => true,
        :listing => name,
        :use_prefix => true
      }.merge!(options)

      commands[name] = BlockCommand.subclass(name, description, options, helper_module, &block)
    end

    def command_class(name, description="No description.", options={}, &block)
      options = {
        :requires_gem => [],
        :keep_retval => false,
        :argument_required => false,
        :interpolate => true,
        :shellwords => true,
        :listing => name,
        :use_prefix => true
      }.merge!(options)

      commands[name] = ClassCommand.subclass(name, description, options, helper_module)
      commands[name].class_eval(&block)
      commands[name]
    end

    # Execute a block of code before a command is invoked. The block also
    # gets access to parameters that will be passed to the command and
    # is evaluated in the same context.
    # @param [String, Regexp] name The name of the command.
    # @yield The block to be run before the command.
    # @example Display parameter before invoking command
    #   Pry.commands.before_command("whereami") do |n|
    #     output.puts "parameter passed was #{n}"
    #   end
    def before_command(name, &block)
      cmd = find_command_by_name_or_listing(name)
      cmd.hooks[:before].unshift block
    end

    # Execute a block of code after a command is invoked. The block also
    # gets access to parameters that will be passed to the command and
    # is evaluated in the same context.
    # @param [String, Regexp] name The name of the command.
    # @yield The block to be run after the command.
    # @example Display text 'command complete' after invoking command
    #   Pry.commands.after_command("whereami") do |n|
    #     output.puts "command complete!"
    #   end
    def after_command(name, &block)
      cmd = find_command_by_name_or_listing(name)
      cmd.hooks[:after] << block
    end

    def each &block
      @commands.each(&block)
    end

    # Removes some commands from the set
    # @param [Array<String>] names name of the commands to remove
    def delete(*names)
      names.each do |name|
        cmd = find_command_by_name_or_listing(name)
        commands.delete cmd.name
      end
    end

    # Imports all the commands from one or more sets.
    # @param [Array<CommandSet>] sets Command sets, all of the commands of which
    #   will be imported.
    def import(*sets)
      sets.each do |set|
        commands.merge! set.commands
        helper_module.send :include, set.helper_module
      end
    end

    # Imports some commands from a set
    # @param [CommandSet] set Set to import commands from
    # @param [Array<String>] names Commands to import
    def import_from(set, *names)
      helper_module.send :include, set.helper_module
      names.each do |name|
        cmd = set.find_command_by_name_or_listing(name)
        commands[cmd.name] = cmd
      end
    end

    # @param [String, Regexp] name_or_listing The name or listing name
    #   of the command to retrieve.
    # @return [Command] The command object matched.
    def find_command_by_name_or_listing(name_or_listing)
      if commands[name_or_listing]
        cmd = commands[name_or_listing]
      else
        _, cmd = commands.find { |name, command| command.options[:listing] == name_or_listing }
      end

      raise ArgumentError, "Cannot find a command with name: '#{name_or_listing}'!" if !cmd
      cmd
    end
    protected :find_command_by_name_or_listing

    # Aliases a command
    # @param [String] new_name New name of the command.
    # @param [String] old_name Old name of the command.
    # @param [String, nil] desc New description of the command.
    def alias_command(new_name, old_name, desc="")
      orig_command = find_command_by_name_or_listing(old_name)
      commands[new_name] = orig_command.dup
      commands[new_name].name = new_name
      commands[new_name].description = desc
    end

    # Rename a command. Accepts either actual name or listing name for
    # the `old_name`.
    # `new_name` must be the actual name of the new command.
    # @param [String, Regexp] new_name The new name for the command.
    # @param [String, Regexp] old_name The command's current name.
    # @param [Hash] options The optional configuration parameters,
    #   accepts the same as the `command` method, but also allows the
    #   command description to be passed this way too.
    # @example Renaming the `ls` command and changing its description.
    #   Pry.config.commands.rename "dir", "ls", :description => "DOS friendly ls"
    def rename_command(new_name, old_name, options={})
      cmd = find_command_by_name_or_listing(old_name)

      options = {
        :listing     => new_name,
        :description => cmd.description
      }.merge!(options)

      commands[new_name] = cmd.dup
      commands[new_name].name = new_name
      commands[new_name].description = options.delete(:description)
      commands[new_name].options.merge!(options)
      commands.delete(cmd.name)
    end

    # Sets or gets the description for a command (replacing the old
    # description). Returns current description if no description
    # parameter provided.
    # @param [String, Regexp] name The command name.
    # @param [String] description The command description.
    # @example Setting
    #   MyCommands = Pry::CommandSet.new do
    #     desc "help", "help description"
    #   end
    # @example Getting
    #   Pry.config.commands.desc "amend-line"
    def desc(name, description=nil)
      cmd = find_command_by_name_or_listing(name)
      return cmd.description if !description

      cmd.description = description
    end

    # Defines helpers methods for this command sets.
    # Those helpers are only defined in this command set.
    #
    # @yield A block defining helper methods
    # @example
    #   helpers do
    #     def hello
    #       puts "Hello!"
    #     end
    #
    #     include OtherModule
    #   end
    def helpers(&block)
      helper_module.class_eval(&block)
    end


    # @return [Array] The list of commands provided by the command set.
    def list_commands
      commands.keys
    end

    def run_command(context, name, *args)
      command = commands[name] or raise NoCommandError.new(name, self)
      command.new(context).call_safely(*args)
    end

    private
    def define_default_commands

      command "help", "This menu." do |cmd|
        if !cmd
          output.puts
          help_text = heading("Command List: ") + "\n"

          help_text << commands.map do |key, command|
            if command.description && !command.description.empty?
              "#{command.options[:listing]}".ljust(18) + command.description
            end
          end.compact.sort.join("\n")

          stagger_output(help_text)
        else
          if command = find_command(cmd)
            output.puts command.description
          else
            output.puts "No info for command: #{cmd}"
          end
        end
      end

      command "install-command", "Install a disabled command." do |name|
        require 'rubygems/dependency_installer' unless defined? Gem::DependencyInstaller
        command = find_command(name)

        if command_dependencies_met?(command.options)
          output.puts "Dependencies for #{command.name} are met. Nothing to do."
          next
        end

        output.puts "Attempting to install `#{name}` command..."
        gems_to_install = Array(command.options[:requires_gem])

        gem_install_failed = false
        gems_to_install.each do |g|
          next if gem_installed?(g)
          output.puts "Installing `#{g}` gem..."

          begin
            Gem::DependencyInstaller.new.install(g)
          rescue Gem::GemNotFoundException
            output.puts "Required Gem: `#{g}` not found. Aborting command installation."
            gem_install_failed = true
            next
          end
        end
        next if gem_install_failed

        Gem.refresh
        gems_to_install.each do |g|
          begin
            require g
          rescue LoadError
            output.puts "Required Gem: `#{g}` installed but not found?!. Aborting command installation."
            gem_install_failed = true
          end
        end
        next if gem_install_failed

        output.puts "Installation of `#{name}` successful! Type `help #{name}` for information"
      end
    end
  end
end
