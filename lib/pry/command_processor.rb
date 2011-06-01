require 'forwardable'

class Pry
  class CommandProcessor
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
      !!(command_matched(val)[0])
    end

    def convert_to_regex(obj)
      case obj
      when String
        Regexp.escape(obj)
      else
        obj
      end
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

    # Determine whether a Pry command was matched and return command data
    # and argument string.
    # This method should not need to be invoked directly.
    # @param [String] val The line of input.
    # @return [Array] The command data and arg string pair
    def command_matched(val)
      _, cmd_data = commands.commands.find do |name, cmd_data|
        /^#{convert_to_regex(name)}(?!\S)/ =~ val
      end

      [cmd_data, (Regexp.last_match ? Regexp.last_match.captures : nil), (Regexp.last_match ? Regexp.last_match.end(0) : nil)]
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
      command, captures, pos = command_matched(val)

      # no command was matched, so return to caller
      return if !command

      val.replace interpolate_string(val, target) if command.options[:interpolate]
      arg_string = val[pos..-1].strip
      args = arg_string ? Shellwords.shellwords(arg_string) : []

      options = {
        :val => val,
        :arg_string => arg_string,
        :eval_string => eval_string,
        :nesting => nesting,
        :commands => commands.commands,
        :captures => captures
      }

      execute_command(target, command.name, options, *(captures + args))
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
      context.captures    = options[:captures]
      context.eval_string = options[:eval_string]
      context.arg_string  = options[:arg_string]
      context.command_set = commands

      context.command_processor = self

      ret = commands.run_command(context, command, *args)

      # Tick, tock, im getting rid of this shit soon.
      options[:val].replace("")

      ret
    end
  end
end
