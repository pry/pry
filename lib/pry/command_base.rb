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
      # @yield [command] The action to perform. The parameters in the block
      #   determines the parameters the command will receive.
      def command(name, description="No description.", &block)
        @commands ||= {}
        @command_info ||= {}

        arg_match = '(?:\s+(\S+))?' * 20
        if name.is_a?(Array)
          matcher = []
          name.each do |n|
            matcher << /^#{n}#{arg_match}?/
          end
        else
          matcher = /^#{name}#{arg_match}?/
        end

        commands[matcher] = block
        command_info[name] = description
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
          out.puts "#{Array(k).first}".ljust(18) + v
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

    def self.inherited(klass)
      klass.commands = commands.dup
      klass.command_info = command_info.dup
    end
  end
end
