require 'forwardable'

class Pry
  class REPL
    extend Forwardable
    attr_accessor :pry

    def_delegators :pry, :input, :output

    # Start a new Pry::REPL wrapping a pry created with the given options.
    #
    # @option options (see Pry#initialize)
    def self.start(options)
      new(Pry.new(options)).start
    end

    # Create a new REPL.
    #
    # @param [Pry] pry  The instance of pry in which to eval code.
    # @option options [Object] :target  The target to REPL on.
    def initialize(pry, options = {})
      @pry    = pry
      @indent = Pry::Indent.new

      if options[:target]
        @pry.push_binding options[:target]
      end
    end

    # Start the read-eval-print-loop.
    #
    # @return [Object]  anything returned by the user from within Pry
    # @raise [Exception]  anything raise-up'd by the user from within Pry
    def start
      prologue
      repl
    ensure
      epilogue
    end

    private

    # Set up the repl session
    def prologue
      pry.exec_hook :before_session, pry.output, pry.current_binding, pry
      # Clear the line before starting Pry. This fixes the issue discussed here:
      # https://github.com/pry/pry/issues/566
      if Pry.config.correct_indent
        Kernel.print Pry::Helpers::BaseHelpers.windows_ansi? ? "\e[0F" : "\e[0G"
      end
    end

    # The actual read-eval-print-loop.
    #
    # This object is responsible for reading and looping, and it delegates
    # to Pry for the evaling and printing.
    #
    # @return [Object]  anything returned by the user from Pry
    # @raise [Exception]  anything raise-up'd by the user from Pry
    def repl
      loop do
        case val = read
        when :control_c
          output.puts ""
          pry.reset_eval_string
        when :no_more_input
          output.puts "" if output.tty?
          break
        else
          output.puts "" if val.nil? && output.tty?
          return pry.exit_value unless pry.eval(val)
        end
      end
    end

    # Clean-up after the repl session.
    def epilogue
      pry.exec_hook :after_session, pry.output, pry.current_binding, pry
    end

    # Read a line of input from the user, special handling for:
    #
    # @return [nil] on <ctrl+d>
    # @return [:control_c] on <ctrl+c>
    # @return [:no_more_input] on EOF from Pry.input
    # @return [String] The line from the user
    def read
      @indent.reset if pry.eval_string.empty?

      current_prompt = pry.select_prompt

      indentation = Pry.config.auto_indent ? @indent.current_prefix : ''

      begin
        val = read_line("#{current_prompt}#{indentation}")

      # Handle <Ctrl+C> like Bash: empty the current input buffer, but don't
      # quit.  This is only for MRI 1.9; other versions of Ruby don't let you
      # send Interrupt from within Readline.
      rescue Interrupt
        val = :control_c
      end

      # Return nil for EOF, :no_more_input for error, or :control_c for <Ctrl-C>
      return val unless String === val

      if Pry.config.auto_indent
        original_val = "#{indentation}#{val}"
        indented_val = @indent.indent(val)

        if output.tty? && @indent.should_correct_indentation?
          output.print @indent.correct_indentation(
            current_prompt, indented_val,
            original_val.length - indented_val.length
          )
          output.flush
        end
      else
        indented_val = val
      end

      indented_val
    end

    # Manage switching of input objects on encountering EOFErrors
    #
    # @return [:no_more_input] if no more input can be read.
    # @return [String?]
    def handle_read_errors
      should_retry = true
      exception_count = 0
      begin
        yield
      rescue EOFError
        pry.input = Pry.config.input
        if !should_retry
          output.puts "Error: Pry ran out of things to read from! Attempting to break out of REPL."
          return :no_more_input
        end
        should_retry = false
        retry

      rescue Interrupt
        raise

      # If we get a random error when trying to read a line we don't want to automatically
      # retry, as the user will see a lot of error messages scroll past and be unable to do
      # anything about it.
      rescue RescuableException => e
        puts "Error: #{e.message}"
        output.puts e.backtrace
        exception_count += 1
        if exception_count < 5
          retry
        end
        puts "FATAL: Pry failed to get user input using `#{input}`."
        puts "To fix this you may be able to pass input and output file descriptors to pry directly. e.g."
        puts "  Pry.config.input = STDIN"
        puts "  Pry.config.output = STDOUT"
        puts "  binding.pry"
        return :no_more_input
      end
    end

    # Returns the next line of input to be used by the pry instance.
    # @param [String] current_prompt The prompt to use for input.
    # @return [String?] The next line of input, nil on <ctrl+d>
    def read_line(current_prompt)
      handle_read_errors do
        if defined? Coolline and input.is_a? Coolline
          input.completion_proc = proc do |cool|
            completions = @pry.complete cool.completed_word
            completions.compact
          end
        elsif input.respond_to? :completion_proc=
          input.completion_proc = proc do |input|
            @pry.complete input
          end
        end

        if input == Readline
          input.readline(current_prompt, false) # false since we'll add it manually
        elsif defined? Coolline and input.is_a? Coolline
          input.readline(current_prompt)
        else
          if input.method(:readline).arity == 1
            input.readline(current_prompt)
          else
            input.readline
          end
        end
      end
    end
  end
end
