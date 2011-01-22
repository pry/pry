class Pry

  # Basic command functionality. All user-defined commands must
  # inherit from this class. It provides the `command` method.
  class CommandBase
    class << self
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
      def command(names, description="No description.", &block)
        @commands ||= {}

        Array(names).each do |name|
          commands[name] = { :description => description, :action => block }
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
        action = opts[:commands][name][:action]
        instance_exec(*args, &action)
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
    end
    
    command "help", "This menu." do |cmd|
      command_info = opts[:commands]
      param = cmd

      if !param
        output.puts "Command list:"
        output.puts "--"
        command_info.each do |k, data|
          output.puts "#{k}".ljust(18) + data[:description] if !data[:description].empty?
        end
      else
        if command_info[param]
          output.puts command_info[param][:description]
        else
          output.puts "No info for command: #{param}"
        end
      end
    end

    # Ensures that commands can be inherited
    def self.inherited(klass)
      klass.commands = commands.dup
    end
    
  end
end
