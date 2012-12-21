require 'forwardable'

class Pry
  class REPL
    extend Forwardable
    attr_accessor :pry

    def_delegators :pry, :input, :output, :input_stack

    def self.start(options)
      new(options).start
    end

    def initialize(options)
      @pry = Pry.new(options)
      @indent = Pry::Indent.new
    end

    def start
      repl_prologue

      # FIXME: move these catchers back into Pry#accept_line
      break_data = nil
      exception = catch(:raise_up) do
        break_data = catch(:breakout) do
          repl
        end
        exception = false
      end

      raise exception if exception

      break_data
    ensure
      repl_epilogue
    end

    private

    def repl_prologue
      pry.exec_hook :before_session, pry.output, pry.current_binding, pry

      # Clear the line before starting Pry. This fixes the issue discussed here:
      # https://github.com/pry/pry/issues/566
      if Pry.config.auto_indent
        Kernel.print Pry::Helpers::BaseHelpers.windows_ansi? ? "\e[0F" : "\e[0G"
      end

    end

    def repl
      loop do
        case val = retrieve_line
        when :control_c
          output.puts ""
          pry.reset_line
        when :end_of_file
          output.puts "" if output.tty?
          pry.accept_eof
        else
          pry.accept_line val
        end
      end
    end

    # Clean-up after the repl session.
    def repl_epilogue
      pry.exec_hook :after_session, pry.output, pry.current_binding, pry

      Pry.save_history if Pry.config.history.should_save
    end

    # Read and process a line of input -- check for ^D, determine which prompt to
    # use, rewrite the indentation if `Pry.config.auto_indent` is enabled, and,
    # if the line is a command, process it and alter the @eval_string accordingly.
    #
    # @return [String] The line received.
    def retrieve_line
      @indent.reset if pry.eval_string.empty?

      current_prompt = pry.select_prompt
      completion_proc = Pry.config.completer.build_completion_proc(pry.current_binding, pry,
                                                          pry.instance_eval(&pry.custom_completions))

      safe_completion_proc = proc{ |*a| Pry.critical_section{ completion_proc.call(*a) } }

      indentation = Pry.config.auto_indent ? @indent.current_prefix : ''

      begin
        val = readline("#{current_prompt}#{indentation}", safe_completion_proc)

      # Handle <Ctrl+C> like Bash, empty the current input buffer but do not quit.
      # This is only for ruby-1.9; other versions of ruby do not let you send Interrupt
      # from within Readline.
      rescue Interrupt
        return :control_c
      end

      # invoke handler if we receive EOF character (^D)
      return :end_of_file unless val

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

      Pry.history << indented_val if interactive?

      indented_val
    end

    # Is the user typing into this pry instance directly?
    # @return [Boolean]
    def interactive?
      !input.is_a?(StringIO)
    end

    # Manage switching of input objects on encountering EOFErrors
    def handle_read_errors
      should_retry = true
      exception_count = 0
      begin
        yield
      rescue EOFError
        if input_stack.empty?
          pry.input = Pry.config.input
          if !should_retry
            output.puts "Error: Pry ran out of things to read from! Attempting to break out of REPL."
            throw(:breakout)
          end
          should_retry = false
        else
          pry.input = input_stack.pop
        end

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
        throw(:breakout)
      end
    end

    # Returns the next line of input to be used by the pry instance.
    # This method should not need to be invoked directly.
    # @param [String] current_prompt The prompt to use for input.
    # @return [String] The next line of input.
    def readline(current_prompt="> ", completion_proc=nil)
      handle_read_errors do
        if defined? Coolline and input.is_a? Coolline
          input.completion_proc = proc do |cool|
            completions = completion_proc.call cool.completed_word
            completions.compact
          end
        elsif input.respond_to? :completion_proc=
          input.completion_proc = completion_proc
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
