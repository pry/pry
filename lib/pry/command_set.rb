class Pry
  class NoCommandError < StandardError
    def initialize(name, owner)
      super "Command '#{name}' not found in command set #{owner}"
    end
  end

  # This class used to create sets of commands. Commands can be impoted from
  # different sets, aliased, removed, etc.
  class CommandSet
    class Command < Struct.new(:name, :description, :options, :block)
      def call(context, *args)
        if stub_block = options[:stub_info]
          context.instance_eval(&stub_block)
        else
          ret = context.instance_exec(*args, &block)
          ret if options[:keep_retval]
        end
      end
    end

    include Pry::Helpers::BaseHelpers

    attr_reader :commands
    attr_reader :name

    # @param [Symbol] name Name of the command set
    # @param [Array<CommandSet>] imported_sets Sets which will be imported
    #   automatically
    # @yield Optional block run to define commands
    def initialize(name, *imported_sets, &block)
      @name     = name
      @commands = {}

      define_default_commands
      import(*imported_sets)

      instance_eval(&block) if block
    end

    # Defines a new Pry command.
    # @param [String, Array] names The name of the command (or array of
    #   command name aliases).
    # @param [String] description A description of the command.
    # @param [Hash] options The optional configuration parameters.
    # @option options [Boolean] :keep_retval Whether or not to use return value
    #   of the block for return of `command` or just to return `nil`
    #   (the default).
    # @yield The action to perform. The parameters in the block
    #   determines the parameters the command will receive. All
    #   parameters passed into the block will be strings. Successive
    #   command parameters are separated by whitespace at the Pry prompt.
    # @example
    #   MyCommands = Pry::CommandSet.new :mine do
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
    def command(names, description="No description.", options={}, &block)
      first_name = Array(names).first

      options = {:requires_gem => []}.merge(options)

      unless command_dependencies_met? options
        gems_needed = Array(options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }

        options[:stub_info] = proc do
          output.puts "\n#{first_name} requires the following gems to be installed: #{(gems_needed.join(", "))}"
          output.puts "Command not available due to dependency on gems: `#{gems_not_installed.join(", ")}` not being met."
          output.puts "Type `install #{first_name}` to install the required gems and activate this command."
        end
      end

      Array(names).each do |name|
        commands[name] = Command.new(name, description, options, block)
      end
    end

    # Removes some commands from the set
    # @param [Arary<String>] names name of the commands to remove
    def delete(*names)
      names.each { |name| commands.delete name }
    end

    # Imports all the commands from one or more sets.
    # @param [Array<CommandSet>] sets Command sets, all of the commands of which
    #   will be imported.
    def import(*sets)
      sets.each { |set| commands.merge! set.commands }
    end

    # Imports some commands from a set
    # @param [CommandSet] set Set to import commands from
    # @param [Array<String>] names Commands to import
    def import_from(set, *names)
      names.each { |name| commands[name] = set.commands[name] }
    end

    # Aliases a command
    # @param [String] new_name New name of the command.
    # @param [String] old_name Old name of the command.
    # @pasam [String, nil] desc New description of the command.
    def alias_command(new_name, old_name, desc = nil)
      commands[new_name] = commands[old_name].dup
      commands[new_name].name = new_name
      commands[new_name].description = desc if desc
    end

    # Runs a command.
    # @param [Object] context Object which will be used as self during the
    #   command.
    # @param [String] name Name of the command to be run
    # @param [Array<Object>] args Arguments passed to the command
    # @raise [NoCommandError] If the command is not defined in this set
    def run_command(context, name, *args)
      if command = commands[name]
        command.call(context, *args)
      else
        raise NoCommandError.new(name, self)
      end
    end

    # Sets the description for a command (replacing the old
    # description.)
    # @param [String] name The command name.
    # @param [String] description The command description.
    # @example
    #   MyCommands = Pry::CommandSet.new :test do
    #     desc "help", "help description"
    #   end
    def desc(name, description)
      commands[name].description = description
    end

    private
    def define_default_commands
      command "help", "This menu." do |cmd|
        if !cmd
          output.puts
          help_text = heading("Command List: ") + "\n"

          commands.each do |key, command|
            if command.description
              help_text << "#{key}".ljust(18) + command.description + "\n"
            end
          end

          stagger_output(help_text)
        else
          if command = commands[cmd]
            output.puts command.description
          else
            output.puts "No info for command: #{cmd}"
          end
        end
      end

      command "install", "Install a disabled command." do |name|
        stub_info = commands[name].options[:stub_info]

        if !stub_info
          output.puts "Not a command stub. Nothing to do."
          next
        end

        output.puts "Attempting to install `#{name}` command..."
        gems_to_install = Array(commands[name].options[:requires_gem])

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
        commands[name].options.delete :stub_info
        output.puts "Installation of `#{name}` successful! Type `help #{name}` for information"
      end
    end
  end
end
