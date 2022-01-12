# frozen_string_literal: true

class Pry
  class REPL
    extend Pry::Forwardable
    def_delegators :@pry, :input, :output

    # @return [Pry] The instance of {Pry} that the user is controlling.
    attr_accessor :pry

    # Instantiate a new {Pry} instance with the given options, then start a
    # {REPL} instance wrapping it.
    # @option options See {Pry#initialize}
    def self.start(options)
      new(Pry.new(options)).start
    end

    # Create an instance of {REPL} wrapping the given {Pry}.
    # @param [Pry] pry The instance of {Pry} that this {REPL} will control.
    # @param [Hash] options Options for this {REPL} instance.
    # @option options [Object] :target The initial target of the session.
    def initialize(pry, options = {})
      @pry    = pry
      @indent = Pry::Indent.new(pry)

      @readline_output = nil

      @pry.push_binding options[:target] if options[:target]
    end

    # Start the read-eval-print loop.
    # @return [Object?] If the session throws `:breakout`, return the value
    #   thrown with it.
    # @raise [Exception] If the session throws `:raise_up`, raise the exception
    #   thrown with it.
    def start
      prologue
      Pry::InputLock.for(:all).with_ownership { repl }
    ensure
      epilogue
    end

    private

    # Set up the repl session.
    # @return [void]
    def prologue
      pry.exec_hook :before_session, pry.output, pry.current_binding, pry

      return unless pry.config.correct_indent

      # Clear the line before starting Pry. This fixes issue #566.
      output.print "\e[G"
    end

    # The actual read-eval-print loop.
    #
    # The {REPL} instance is responsible for reading and looping, whereas the
    # {Pry} instance is responsible for evaluating user input and printing
    # return values and command output.
    #
    # @return [Object?] If the session throws `:breakout`, return the value
    #   thrown with it.
    # @raise [Exception] If the session throws `:raise_up`, raise the exception
    #   thrown with it.
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

    # Clean up after the repl session.
    # @return [void]
    def epilogue
      pry.exec_hook :after_session, pry.output, pry.current_binding, pry
    end

    # Read a line of input from the user.
    # @return [String] The line entered by the user.
    # @return [nil] On `<Ctrl-D>`.
    # @return [:control_c] On `<Ctrl+C>`.
    # @return [:no_more_input] On EOF.
    def read
      @indent.reset if pry.eval_string.empty?

      current_prompt = pry.select_prompt
      indentation = pry.config.auto_indent ? @indent.current_prefix : ''

      val = read_line("#{current_prompt}#{indentation}")

      # Return nil for EOF, :no_more_input for error, or :control_c for <Ctrl-C>
      return val unless val.is_a?(String) && pry.config.auto_indent

      indented_val = @indent.indent(val)

      if output.tty? && pry.config.correct_indent && Pry::Helpers::BaseHelpers.use_ansi_codes?
        clean_prompt = Pry::Helpers::Text.strip_color(current_prompt)
        lines = output.calculate_num_lines(clean_prompt.length + indented_val.length)

        # move cursor to the beginning of the line, and up N lines (^[nF)
        # then move right the length of the prompt (^[nC)
        move_cursor = "\e[#{lines}F\e[#{clean_prompt.length}C"

        colored_code = Pry::Helpers::BaseHelpers.colorize_code(indented_val)
        clear_rest_of_line = "\e[K"

        output.print move_cursor, colored_code, clear_rest_of_line
        output.puts
        output.flush
      end

      indented_val
    end

    # Manage switching of input objects on encountering `EOFError`s.
    # @return [Object] Whatever the given block returns.
    # @return [:no_more_input] Indicates that no more input can be read.
    def handle_read_errors
      should_retry = true
      exception_count = 0

      begin
        yield
      rescue EOFError
        pry.config.input = Pry.config.input
        unless should_retry
          output.puts "Error: Pry ran out of things to read from! " \
            "Attempting to break out of REPL."
          return :no_more_input
        end
        should_retry = false
        retry

      # Handle <Ctrl+C> like Bash: empty the current input buffer, but don't
      # quit.  This is only for MRI 1.9; other versions of Ruby don't let you
      # send Interrupt from within Readline.
      rescue Interrupt
        return :control_c

      # If we get a random error when trying to read a line we don't want to
      # automatically retry, as the user will see a lot of error messages
      # scroll past and be unable to do anything about it.
      rescue RescuableException => e
        puts "Error: #{e.message}"
        output.puts e.backtrace
        exception_count += 1
        retry if exception_count < 5
        puts "FATAL: Pry failed to get user input using `#{input}`."
        puts "To fix this you may be able to pass input and output file " \
          "descriptors to pry directly. e.g."
        puts "  Pry.config.input = STDIN"
        puts "  Pry.config.output = STDOUT"
        puts "  binding.pry"
        return :no_more_input
      end
    end

    # Returns the next line of input to be sent to the {Pry} instance.
    # @param [String] current_prompt The prompt to use for input.
    # @return [String?] The next line of input, or `nil` on <Ctrl-D>.
    def read_line(current_prompt)

      if pry.config.escape_prompt
        current_prompt = current_prompt.gsub(/(\e\[[\d;]*m)/, "\001\\1\002")
        current_prompt.gsub!(/[\001\002]{2,}/) { |match| match[0] }
      end

      handle_read_errors do
        if coolline_available?
          input.completion_proc = proc do |cool|
            completions = @pry.complete cool.completed_word
            completions.compact
          end
        elsif input.respond_to? :completion_proc=
          input.completion_proc = proc do |inp|
            @pry.complete inp
          end
        end

        if readline_available?
          set_readline_output
          input_readline(current_prompt, false) # false since we'll add it manually
        elsif coolline_available?
          input_readline(current_prompt)
        elsif input.method(:readline).arity == 1
          input_readline(current_prompt)
        else
          input_readline
        end
      end
    end

    def input_readline(*args)
      Pry::InputLock.for(:all).interruptible_region do
        i = input
        i.readline(*args)
      end
    end

    def readline_available?
      defined?(Readline) && input == Readline
    end

    def coolline_available?
      defined?(Coolline) && input.is_a?(Coolline)
    end

    # If `$stdout` is not a tty, it's probably a pipe.
    # @example
    #   # `piping?` returns `false`
    #   % pry
    #   [1] pry(main)
    #
    #   # `piping?` returns `true`
    #   % pry | tee log
    def piping?
      return false unless $stdout.respond_to?(:tty?)

      !$stdout.tty? && $stdin.tty? && !Helpers::Platform.windows?
    end

    # @return [void]
    def set_readline_output
      return if @readline_output

      @readline_output = (Readline.output = Pry.config.output) if piping?
    end
  end
end
