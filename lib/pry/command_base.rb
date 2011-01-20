class Pry

  # Basic command functionality. All user-defined commands must
  # inherit from this class. It provides the `command` method.
  class CommandBase
    class << self
      attr_accessor :commands
      attr_accessor :command_info
      attr_accessor :opts

      # private because we want to force function style invocation. We require
      # that the location where the block is defined has the `opts`
      # method in scope.
      private
      
      # Defines a new Pry command.
      # @param [String, Array] name The name of the command (or array of
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
      def command(name, description="No description.", &block)
        @commands ||= {}
        @command_info ||= {}

        arg_match = '(?:\s+(\S+))?' * 20
        if name.is_a?(Array)
          name.each do |n|
            matcher = /^#{n}(?!\S)#{arg_match}?/
            commands[matcher] = block
            command_info[n] = description
          end
        else
          matcher = /^#{name}(?!\S)#{arg_match}?/
          commands[matcher] = block
          command_info[name] = description
        end

      end
    end
    command "help", "This menu." do |cmd|
      out = opts[:output]
      command_info = opts[:command_info]
      param = cmd

      if !param
        out.puts "Command list:"
        out.puts "--"
        command_info.each do |k, v|
          out.puts "#{k}".ljust(18) + v
        end
      else
        key = command_info.keys.find { |v| Array(v).any? { |k| k === param } }
        if key
          out.puts command_info[key]
        else
          out.puts "No info for command: #{param}"
        end
      end
    end

    # Ensures that commands can be inherited
    def self.inherited(klass)
      klass.commands = commands.dup
      klass.command_info = command_info.dup
    end
  end
end
