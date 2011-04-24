require 'rubygems/dependency_installer'
require "pry/command_base_helpers"

class Pry

  # Basic command functionality. All user-defined commands must
  # inherit from this class. It provides the `command` method.
  class CommandBase
    class << self
      include CommandBaseHelpers

      attr_accessor :commands
      attr_accessor :opts, :output, :target

      # private because we want to force function style invocation. We require
      # that the location where the block is defined has the `opts`
      # method in scope.
      private

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
      #   class MyCommands < Pry::CommandBase
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
        options = {
          :keep_retval => false,
          :requires_gem => nil
        }.merge!(options)

        @commands ||= {}

        if command_dependencies_met?(options)
          Array(names).each do |name|
            commands[name] = {
              :description => description,
              :action => block,
              :keep_retval => options[:keep_retval]
            }
          end
        else
          create_command_stub(names, description, options, block)
        end
      end

      # Delete a command or an array of commands.
      # Useful when inheriting from another command set and pruning
      # those commands down to the ones you want.
      # @param [Array<String>] names The command name or array
      #   of command names you want to delete
      # @example Deleteing inherited commands
      #   class MyCommands < Pry::Commands
      #     delete "show_method", "show_imethod", "show_doc", "show_idoc"
      #   end
      #   Pry.commands = MyCommands
      def delete(*names)
        names.each { |name| commands.delete(name) }
      end

      # Execute a command (this enables commands to call other commands).
      # @param [String] name The command to execute
      # @param [Array] args The parameters to pass to the command.
      # @example Wrap one command with another
      #   class MyCommands < Pry::Commands
      #     command "ls2" do
      #       output.puts "before ls"
      #       run "ls"
      #       output.puts "after ls"
      #     end
      #   end
      def run(name, *args)
        command_processor =  CommandProcessor.new(target.eval('_pry_'))

        if command_processor.system_command?(name)
          command_processor.execute_system_command("#{name} #{args.join(' ')}", target)
        else
          raise "#{name.inspect} is not a valid pry command." unless opts[:commands].include? name
          action = opts[:commands][name][:action]
          instance_exec(*args, &action)
        end
      end

      # Import commands from another command object.
      # @param [Pry::CommandBase] klass The class to import from (must
      #   be a subclass of `Pry::CommandBase`)
      # @param [Array<String>] names The commands to import.
      # @example
      #   class MyCommands < Pry::CommandBase
      #     import_from Pry::Commands, "ls", "show_method", "cd"
      #   end
      def import_from(klass, *names)
        imported_hash = Hash[klass.commands.select { |k, v| names.include?(k) }]
        commands.merge!(imported_hash)
      end

      # Create an alias for a command.
      # @param [String] new_command The alias name.
      # @param [String] orig_command The original command name.
      # @param [String] desc The optional description.
      # @example
      #   class MyCommands < Pry::CommandBase
      #     alias_command "help_alias", "help"
      #   end
      def alias_command(new_command_name, orig_command_name, desc=nil)
        commands[new_command_name] = commands[orig_command_name].dup
        commands[new_command_name][:description] = desc if desc
      end

      # Set the description for a command (replacing the old
      # description.)
      # @param [String] name The command name.
      # @param [String] description The command description.
      # @example
      #   class MyCommands < Pry::CommandBase
      #     desc "help", "help description"
      #   end
      def desc(name, description)
        commands[name][:description] = description
      end
    end

    command "help", "This menu." do |cmd|
      command_info = opts[:commands]

      if !cmd
        output.puts
        help_text = heading("Command List:") + "\n"
        command_info.each do |k, data|
          if !data[:stub_info]
            help_text << ("#{k}".ljust(18) + data[:description] + "\n") if !data[:description].empty?
          else
            help_text << (bold("#{k}".ljust(18) + data[:description] + "\n")) if !data[:description].empty?
          end
        end
        stagger_output(help_text)
      else
        if command_info[cmd]
          output.puts command_info[cmd][:description]
        else
          output.puts "No info for command: #{cmd}"
        end
      end
    end

    command "install", "Install a disabled command." do |name|
      stub_info = commands[name][:stub_info]

      if !stub_info
        output.puts "Not a command stub. Nothing to do."
        next
      end

      output.puts "Attempting to install `#{name}` command..."
      gems_to_install = Array(stub_info[:requires_gem])

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
      load "#{File.dirname(__FILE__)}/commands.rb"
      output.puts "Installation of `#{name}` successful! Type `help #{name}` for information"
    end

    # Ensures that commands can be inherited
    def self.inherited(klass)
      klass.commands = commands.dup
    end

  end
end
