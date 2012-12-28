require 'forwardable'

class Pry
  class REPL
    extend Forwardable
    attr_accessor :pry

    def_delegators :pry, :input, :output

    def self.start(options)
      new(Pry.new(options)).start
    end

    def initialize(pry, options = {})
      @pry    = pry
      @indent = Pry::Indent.new

      if options[:target]
        @pry.push_binding options[:target]
      end
    end

    def start
      prologue
      repl
    ensure
      epilogue
    end

    private

    def prologue
      pry.exec_hook :before_session, pry.output, pry.current_binding, pry
      # Clear the line before starting Pry. This fixes the issue discussed here:
      # https://github.com/pry/pry/issues/566
      if Pry.config.auto_indent
        Kernel.print Pry::Helpers::BaseHelpers.windows_ansi? ? "\e[0F" : "\e[0G"
      end
    end

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

      Pry.save_history if Pry.config.history.should_save
    end

    # Read and process a line of input -- check for ^D, determine which prompt to
    # use, rewrite the indentation if `Pry.config.auto_indent` is enabled, and,
    # if the line is a command, process it and alter the @eval_string accordingly.
    #
    # @return [String] The line received.
    def read
      @indent.reset if pry.eval_string.empty?

      current_prompt = pry.select_prompt

      indentation = Pry.config.auto_indent ? @indent.current_prefix : ''

      begin
        val = read_line("#{current_prompt}#{indentation}")

      # Handle <Ctrl+C> like Bash, empty the current input buffer but do not quit.
      # This is only for ruby-1.9; other versions of ruby do not let you send Interrupt
      # from within Readline.
      rescue Interrupt
        return :control_c
      end

      # return nil for EOF
      return unless val

      if Pry.config.auto_indent && !input.is_a?(StringIO)
        original_val = "#{indentation}#{val}"
        indented_val = @indent.indent(val)

        if output.tty? && Pry::Helpers::BaseHelpers.use_ansi_codes? && Pry.config.correct_indent
          output.print @indent.correct_indentation(current_prompt, indented_val, original_val.length - indented_val.length)
          output.flush
        end
      else
        indented_val = val
      end

      indented_val
    end

    # Manage switching of input objects on encountering EOFErrors
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

      # Interrupts are handled in r() because they need to tweak @eval_string
      # TODO: Refactor this baby.
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
    # @return [String] The next line of input.
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
