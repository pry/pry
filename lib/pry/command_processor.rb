require 'forwardable'

class Pry
  class CommandProcessor
    SYSTEM_COMMAND_DELIMITER = "."
    SYSTEM_COMMAND_REGEX = /^#{Regexp.escape(SYSTEM_COMMAND_DELIMITER)}(.*)/

    extend Forwardable

    attr_accessor :pry_instance

    def initialize(pry_instance)
      @pry_instance = pry_instance
    end

    def_delegators :@pry_instance, :commands, :nesting, :output

    # Is the string a command valid?
    # @param [String] val The string passed in from the Pry prompt.
    # @return [Boolean] Whether the string is a valid command.
    def valid_command?(val)
      system_command?(val) || pry_command?(val)
    end

    # Is the string a valid system command?
    # @param [String] val The string passed in from the Pry prompt.
    # @return [Boolean] Whether the string is a valid system command.
    def system_command?(val)
      !!(SYSTEM_COMMAND_REGEX =~ val)
    end

    # Is the string a valid pry command?
    # A Pry command is a command that is not a system command.
    # @param [String] val The string passed in from the Pry prompt.
    # @return [Boolean] Whether the string is a valid Pry command.
    def pry_command?(val)
      !!command_matched(val).first
    end

    # Revaluate the string (str) and perform interpolation.
    # @param [String] str The string to reevaluate with interpolation.
    # @param [Binding] target The context where the string should be
    #   reevaluated in.
    # @return [String] The reevaluated string with interpolations
    #   applied (if any).
    def interpolate_string(str, target)
      dumped_str = str.dump
      dumped_str.gsub!(/\\\#\{/, '#{')
      target.eval(dumped_str)
    end

    # Execute a given system command.
    # The commands first have interpolation applied against the
    # `target` context.
    # All system command are forwarded to a shell. Note that the `cd`
    # command is special-cased and is converted internallly to a `Dir.chdir`
    # @param [String] val The system command to execute.
    # @param [Binding] target The context in which to perform string interpolation.
    def execute_system_command(val, target)
      SYSTEM_COMMAND_REGEX  =~ val
      cmd = interpolate_string($1, target)

      if cmd =~ /^cd\s+(.+)/i
        begin
          @@cd_history ||= []
          if $1 == "-"
            dest = @@cd_history.pop || Dir.pwd
          else
            dest = File.expand_path($1)
          end

          @@cd_history << Dir.pwd
          Dir.chdir(dest)
        rescue Errno::ENOENT
          output.puts "No such directory: #{dest}"
        end
      else
        if !system(cmd)
          output.puts "Error: there was a problem executing system command: #{cmd}"
        end
      end

      # Tick, tock, im getting rid of this shit soon.
      val.replace("")
    end

    # Determine whether a Pry command was matched and return command data
    # and argument string.
    # This method should not need to be invoked directly.
    # @param [String] val The line of input.
    # @return [Array] The command data and arg string pair
    def command_matched(val)
      _, cmd_data = commands.commands.find do |name, cmd_data|
        /^#{Regexp.escape(name)}(?!\S)(?:\s+(.+))?/ =~ val
      end

      [cmd_data, $1]
    end

    # Process Pry commands. Pry commands are not Ruby methods and are evaluated
    # prior to Ruby expressions.
    # Commands can be modified/configured by the user: see `Pry::Commands`
    # This method should not need to be invoked directly - it is called
    # by `Pry#r`.
    # @param [String] val The current line of input.
    # @param [String] eval_string The cumulative lines of input for
    #   multi-line input.
    # @param [Binding] target The receiver of the commands.
    def process_commands(val, eval_string, target)
      def val.clear() replace("") end
      def eval_string.clear() replace("") end

      if system_command?(val)
        execute_system_command(val, target)
        return
      end

      # no command was matched, so return to caller
      return if !pry_command?(val)

      val.replace interpolate_string(val, target)
      command, args_string = command_matched(val)

      args = args_string ? Shellwords.shellwords(args_string) : []

      options = {
        :val => val,
        :eval_string => eval_string,
        :nesting => nesting,
        :commands => commands.commands
      }

      execute_command(target, command.name, options, *args)
    end

    # Execute a Pry command.
    # This method should not need to be invoked directly.
    # @param [Binding] target The target of the Pry session.
    # @param [String] command The name of the command to be run.
    # @param [Hash] options The options to set on the Commands object.
    # @param [Array] args The command arguments.
    def execute_command(target, command, options, *args)
      context = CommandContext.new

      # set some useful methods to be used by the action blocks
      context.opts        = options
      context.target      = target
      context.output      = output
      context.command_set = commands

      ret = commands.run_command(context, command, *args)

      # Tick, tock, im getting rid of this shit soon.
      options[:val].clear

      ret
    end
  end
end
