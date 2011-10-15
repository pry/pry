class Pry
  class NoCommandError < StandardError
    def initialize(name, owner)
      super "Command '#{name}' not found in command set #{owner}"
    end
  end

  # This class is used to create sets of commands. Commands can be imported from
  # different sets, aliased, removed, etc.
  class CommandSet
    class Command < Struct.new(:name, :description, :options, :block)

      def call(context, *args)
        context.command_name = options[:listing]

        if stub_block = options[:stub_info]
          context.instance_eval(&stub_block)
        else
          ret = context.instance_exec(*correct_arg_arity(block.arity, args), &block)
          if options[:keep_retval]
            ret
          else
            Pry::CommandContext::VOID_VALUE
          end
        end
      end

      private
      def correct_arg_arity(arity, args)
        case arity <=> 0
        when -1
          args
        when 0
          []
        when 1
          # another jruby hack
          if Pry::Helpers::BaseHelpers.jruby?
            args[0..(arity - 1)]
          else
            args.values_at 0..(arity - 1)
          end
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

      unless command_dependencies_met? options
        gems_needed = Array(options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }

        options[:stub_info] = proc do
          output.puts "\nThe command '#{name}' is #{Helpers::Text.bold("unavailable")} because it requires the following gems to be installed: #{(gems_not_installed.join(", "))}"
          output.puts "-"
          output.puts "Type `install-command #{name}` to install the required gems and activate this command."
        end
      end

      commands[name] = Command.new(name, description, options, block)
    end

    def each &block
      @commands.each(&block)
    end

    # Removes some commands from the set
    # @param [Array<String>] names name of the commands to remove
    def delete(*names)
      names.each { |name| commands.delete name }
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
      names.each { |name| commands[name] = set.commands[name] }
    end

    # Aliases a command
    # @param [String] new_name New name of the command.
    # @param [String] old_name Old name of the command.
    # @param [String, nil] desc New description of the command.
    def alias_command(new_name, old_name, desc="")
      commands[new_name] = commands[old_name].dup
      commands[new_name].name = new_name
      commands[new_name].description = desc
    end

    # Runs a command.
    # @param [Object] context Object which will be used as self during the
    #   command.
    # @param [String] name Name of the command to be run
    # @param [Array<Object>] args Arguments passed to the command
    # @raise [NoCommandError] If the command is not defined in this set
    def run_command(context, name, *args)
      context.extend helper_module
      command = commands[name]

      if command.nil?
        raise NoCommandError.new(name, self)
      end

      if command.options[:argument_required] && args.empty?
        puts "The command '#{command.name}' requires an argument."
      else
        command.call context, *args
      end
    end

    # Sets the description for a command (replacing the old
    # description.)
    # @param [String] name The command name.
    # @param [String] description The command description.
    # @example
    #   MyCommands = Pry::CommandSet.new do
    #     desc "help", "help description"
    #   end
    def desc(name, description)
      commands[name].description = description
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
        stub_info = command.options[:stub_info]

        if !stub_info
          output.puts "Not a command stub. Nothing to do."
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

        command.options.delete :stub_info
        output.puts "Installation of `#{name}` successful! Type `help #{name}` for information"
      end
    end
  end
end
