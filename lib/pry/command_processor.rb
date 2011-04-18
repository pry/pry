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
          output.puts "=> #{dest.inspect}"
        rescue Errno::ENOENT
          output.puts "No such directory: #{dest}"
        end
      else
        system(cmd)
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
      cmd_data, args_string = command_matched(val)

      args = args_string ? Shellwords.shellwords(args_string) : []
      action = cmd_data[:action]
      keep_retval = cmd_data[:keep_retval]

      options = {
        :val => val,
        :eval_string => eval_string,
        :nesting => nesting,
        :commands => commands.commands
      }

      ret_value = execute_command(target, action, options, *args)

      # return value of block only if :keep_retval is true
      ret_value if keep_retval
    end

    # Execute a Pry command.
    # This method should not need to be invoked directly.
    # @param [Binding] target The target of the Pry session.
    # @param [Proc] action The proc that implements the command.
    # @param [Hash] options The options to set on the Commands object.
    # @param [Array] args The command arguments.
    def execute_command(target, action, options, *args)

      # set some useful methods to be used by the action blocks
      commands.opts = options
      commands.target = target
      commands.output = output

      case action.arity <=> 0
      when -1

        # Use instance_exec() to make the `opts` method, etc available
        ret_val = commands.instance_exec(*args, &action)
      when 1, 0

        # ensure that we get the right number of parameters
        # since 1.8.7 complains about incorrect arity (1.9.2
        # doesn't care)
        args_with_corrected_arity = args.values_at *0..(action.arity - 1)
        ret_val = commands.instance_exec(*args_with_corrected_arity, &action)
      end

      # Tick, tock, im getting rid of this shit soon.
      options[:val].clear

      ret_val
    end
  end
end
