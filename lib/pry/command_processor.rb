require 'forwardable'

class Pry
  class CommandProcessor

    # Wraps the return result of process_commands, indicates if the
    # result IS a command and what kind of command (e.g void)
    class Result
      attr_reader :retval

      def initialize(is_command, keep_retval = false, retval = nil)
        @is_command, @keep_retval, @retval = is_command, keep_retval, retval
      end

      # Is the result a command?
      # @return [Boolean]
      def command?
        @is_command
      end

      # Is the result a command and if it is, is it a void command?
      # (one that does not return a value)
      # @return [Boolean]
      def void_command?
        (command? && !keep_retval?) || retval == CommandContext::VOID_VALUE
      end

      # Is the return value kept for this command? (i.e :keep_retval => true)
      # @return [Boolean]
      def keep_retval?
        @keep_retval
      end
    end

    extend Forwardable

    attr_accessor :pry_instance

    def initialize(pry_instance)
      @pry_instance = pry_instance
    end

    def_delegators :@pry_instance, :commands, :output

    # Is the string a valid command?
    # @param [String] val The string passed in from the Pry prompt.
    # @param [Binding] target The context where the string should be
    #   interpolated in.
    # @return [Boolean] Whether the string is a valid command.
    def valid_command?(val, target=binding)
      !!(command_matched(val, target)[0])
    end

    # Convert the object to a form that can be interpolated into a
    # Regexp cleanly.
    # @return [String] The string to interpolate into a Regexp
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
    #   interpolated in.
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
    # @param [Binding] target The binding to perform string
    #   interpolation against.
    # @return [Array] The command data and arg string pair
    def command_matched(val, target)
      _, cmd_data = commands.commands.find do |name, data|
        prefix = convert_to_regex(Pry.config.command_prefix)
        prefix = "(?:#{prefix})?" unless data.options[:use_prefix]

        command_regex = /^#{prefix}#{convert_to_regex(name)}(?!\S)/

        if command_regex =~ val
          if data.options[:interpolate]
            val.replace(interpolate_string(val, target))
            command_regex =~ val # re-match with the interpolated string
          end
          true
        end
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
    # @return [Pry::CommandProcessor::Result] A wrapper object
    #   containing info about the result of the command processing
    #   (indicating whether it is a command and if it is what kind of
    #   command it is.
    def process_commands(val, eval_string, target)

      command, captures, pos = command_matched(val, target)

      # no command was matched, so return to caller
      return Result.new(false) if !command

      arg_string = val[pos..-1]

      # remove the one leading space if it exists
      arg_string.slice!(0) if arg_string.start_with?(" ")

      if arg_string
        args = command.options[:shellwords] ? Shellwords.shellwords(arg_string) : arg_string.split(" ")
      else
        args = []
      end

      options = {
        :val => val,
        :arg_string => arg_string,
        :eval_string => eval_string,
        :commands => commands.commands,
        :captures => captures
      }

      ret = execute_command(target, command.name, options, *(captures + args))

      Result.new(true, command.options[:keep_retval], ret)
    end

    # Execute a Pry command.
    # This method should not need to be invoked directly.
    # @param [Binding] target The target of the Pry session.
    # @param [String] command The name of the command to be run.
    # @param [Hash] options The options to set on the Commands object.
    # @param [Array] args The command arguments.
    # @return [Object] The value returned by the command
    def execute_command(target, command, options, *args)
      context = CommandContext.new

      # set some useful methods to be used by the action blocks
      context.opts        = options
      context.target      = target
      context.target_self = target.eval('self')
      context.output      = output
      context.captures    = options[:captures]
      context.eval_string = options[:eval_string]
      context.arg_string  = options[:arg_string]
      context.command_set = commands
      context._pry_ = @pry_instance

      context.command_processor = self

      ret = nil
      catch(:command_done) do
        ret = commands.run_command(context, command, *args)
      end

      options[:val].replace("")

      ret
    end
  end
end
