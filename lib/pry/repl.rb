require 'forwardable'

class Pry
  class REPL
    extend Forwardable
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
      @indent = Pry::Indent.new
      @should_try_next_input = true

      if options[:target]
        @pry.push_binding options[:target]
      end

      Pry::InputLock.hook(pry.input)
    end

    # Start the read-eval-print loop.
    # @return [Object?] If the session throws `:breakout`, return the value
    #   thrown with it.
    # @raise [Exception] If the session throws `:raise_up`, raise the exception
    #   thrown with it.
    def start
      prologue
      while should_try_next_input?
        use_next_input
        input.pry_lock.register_ownership { repl }
      end
    ensure
      epilogue
    end

    private

    # Should try next input?
    # @return [bool]
    def should_try_next_input?
      @should_try_next_input
    end

    # Cycle through the inputs
    # Currently just get the config default input, the first one being the
    # command line one.
    def use_next_input
      pry.input = Pry.config.input
      Pry::InputLock.hook(pry.input)
      @should_try_next_input = false
    end

    # Set up the repl session.
    # @return [void]
    def prologue
      pry.exec_hook :before_session, pry.output, pry.current_binding, pry

      # Clear the line before starting Pry. This fixes issue #566.
      if Pry.config.correct_indent
        Kernel.print Pry::Helpers::BaseHelpers.windows_ansi? ? "\e[0F" : "\e[0G"
      end
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
          unless should_try_next_input?
            output.puts "Error: Pry ran out of things to read from! " \
                        "Attempting to break out of REPL."
            output.puts "" if output.tty?
          end
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
      indentation = Pry.config.auto_indent ? @indent.current_prefix : ''

      val = read_line("#{current_prompt}#{indentation}")

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

    # Manage switching of input objects on encountering `EOFError`s.
    # @return [Object] Whatever the given block returns.
    # @return [:no_more_input] Indicates that no more input can be read.
    def handle_read_errors
      exception_count = 0

      begin
        yield
      rescue EOFError
        return :no_more_input

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
        if exception_count < 5
          retry
        end
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
          if !$stdout.tty? && $stdin.tty? && !Pry::Helpers::BaseHelpers.windows?
            Readline.output = File.open('/dev/tty', 'w')
          end
          input_readline(current_prompt, false) # false since we'll add it manually
        elsif defined? Coolline and input.is_a? Coolline
          input_readline(current_prompt)
        else
          if input.method(:readline).arity == 1
            input_readline(current_prompt)
          else
            input_readline
          end
        end
      end
    end

    def input_readline(*args)
      input.pry_lock.interruptible_region do
        input.readline(*args)
      end
    end
  end
end
