require "pry/command_processor.rb"
require "pry/indent"

class Pry

  attr_accessor :input
  attr_accessor :output
  attr_accessor :commands
  attr_accessor :print
  attr_accessor :exception_handler
  attr_accessor :hooks
  attr_accessor :input_stack

  attr_accessor :custom_completions

  attr_accessor :binding_stack

  attr_accessor :last_result
  attr_accessor :last_exception
  attr_accessor :last_file
  attr_accessor :last_dir

  attr_reader :input_array
  attr_reader :output_array

  # Create a new `Pry` object.
  # @param [Hash] options The optional configuration parameters.
  # @option options [#readline] :input The object to use for input.
  # @option options [#puts] :output The object to use for output.
  # @option options [Pry::CommandBase] :commands The object to use for commands.
  # @option options [Hash] :hooks The defined hook Procs
  # @option options [Array<Proc>] :prompt The array of Procs to use for the prompts.
  # @option options [Proc] :print The Proc to use for the 'print'
  #   component of the REPL. (see print.rb)
  def initialize(options={})
    refresh(options)

    @command_processor = CommandProcessor.new(self)
    @binding_stack     = []
    @indent            = Pry::Indent.new
  end

  # Refresh the Pry instance settings from the Pry class.
  # Allows options to be specified to override settings from Pry class.
  # @param [Hash] options The options to override Pry class settings
  #   for this instance.
  def refresh(options={})
    defaults   = {}
    attributes = [
                   :input, :output, :commands, :print,
                   :exception_handler, :hooks, :custom_completions,
                   :prompt, :memory_size, :input_stack
                 ]

    attributes.each do |attribute|
      defaults[attribute] = Pry.send attribute
    end

    defaults.merge!(options).each do |key, value|
      send "#{key}=", value
    end

    true
  end

  # The current prompt.
  # This is the prompt at the top of the prompt stack.
  #
  # @example
  #    self.prompt = Pry::SIMPLE_PROMPT
  #    self.prompt # => Pry::SIMPLE_PROMPT
  #
  # @return [Array<Proc>] Current prompt.
  def prompt
    prompt_stack.last
  end

  def prompt=(new_prompt)
    if prompt_stack.empty?
      push_prompt new_prompt
    else
      prompt_stack[-1] = new_prompt
    end
  end

  # Injects a local variable into the provided binding.
  # @param [String] name The name of the local to inject.
  # @param [Object] value The value to set the local to.
  # @param [Binding] b The binding to set the local on.
  # @return [Object] The value the local was set to.
  def inject_local(name, value, b)
    Thread.current[:__pry_local__] = value
    b.eval("#{name} = Thread.current[:__pry_local__]")
  ensure
    Thread.current[:__pry_local__] = nil
  end

  # @return [Integer] The maximum amount of objects remembered by the inp and
  #   out arrays. Defaults to 100.
  def memory_size
    @output_array.max_size
  end

  def memory_size=(size)
    @input_array  = Pry::HistoryArray.new(size)
    @output_array = Pry::HistoryArray.new(size)
  end

  # Make sure special locals exist at start of session
  def initialize_special_locals(target)
    inject_local("_in_", @input_array, target)
    inject_local("_out_", @output_array, target)
    inject_local("_pry_", self, target)
    inject_local("_ex_", nil, target)
    inject_local("_file_", nil, target)
    inject_local("_dir_", nil, target)

    # without this line we get 1 test failure, ask Mon_Ouie
    set_last_result(nil, target)
    inject_local("_", nil, target)
  end
  private :initialize_special_locals

  def inject_special_locals(target)
    special_locals.each_pair do |name, value|
      inject_local(name, value, target)
    end
  end

  def special_locals
    {
      :_in_ => @input_array,
      :_out_ => @output_array,
      :_pry_ => self,
      :_ex_ => last_exception,
      :_file_ => last_file,
      :_dir_ => last_dir,
      :_ => last_result
    }
  end

  # Initialize the repl session.
  # @param [Binding] target The target binding for the session.
  def repl_prologue(target)
    hooks.exec_hook :before_session, output, target, self
    initialize_special_locals(target)

    @input_array << nil # add empty input so _in_ and _out_ match

    Pry.active_sessions += 1
    binding_stack.push target
  end

  # Clean-up after the repl session.
  # @param [Binding] target The target binding for the session.
  def repl_epilogue(target)
    hooks.exec_hook :after_session, output, target, self

    Pry.active_sessions -= 1
    binding_stack.pop
    Pry.save_history if Pry.config.history.should_save && Pry.active_sessions == 0
  end

  # Start a read-eval-print-loop.
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the Pry session
  # @return [Object] The target of the Pry session or an explictly given
  #   return value. If given return value is `nil` or no return value
  #   is specified then `target` will be returned.
  # @example
  #   Pry.new.repl(Object.new)
  def repl(target=TOPLEVEL_BINDING)
    target = Pry.binding_for(target)
    target_self = target.eval('self')

    repl_prologue(target)

    break_data = catch(:breakout) do
      loop do
        rep(binding_stack.last)
      end
    end

    repl_epilogue(target)
    break_data || nil
  end

  # Perform a read-eval-print.
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the read-eval-print
  # @example
  #   Pry.new.rep(Object.new)
  def rep(target=TOPLEVEL_BINDING)
    target = Pry.binding_for(target)
    result = re(target)

    show_result(result) if should_print?
  end

  # Perform a read-eval
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the read-eval-print
  # @return [Object] The result of the eval or an `Exception` object in case of
  #   error. In the latter case, you can check whether the exception was raised
  #   or is just the result of the expression using #last_result_is_exception?
  # @example
  #   Pry.new.re(Object.new)
  def re(target=TOPLEVEL_BINDING)
    target = Pry.binding_for(target)

    compl = Pry::InputCompleter.build_completion_proc(target,
                                                      instance_eval(&custom_completions))

    if defined? Coolline and input.is_a? Coolline
      input.completion_proc = proc do |cool|
        compl.call cool.completed_word
      end
    elsif input.respond_to? :completion_proc=
      input.completion_proc = compl
    end

    # It's not actually redundant to inject them continually as we may have
    # moved into the scope of a new Binding (e.g the user typed `cd`)
    inject_special_locals(target)

    code = r(target)

    result = set_last_result(target.eval(code, Pry.eval_path, Pry.current_line), target)
    result
  rescue RescuableException => e
    result = set_last_exception(e, target)
  ensure
    update_input_history(code)
    hooks.exec_hook :after_eval, result, self
  end

  # Perform a read.
  # If no parameter is given, default to top-level (main).
  # This is a multi-line read; so the read continues until a valid
  # Ruby expression is received.
  # Pry commands are also accepted here and operate on the target.
  # @param [Object, Binding] target The receiver of the read.
  # @param [String] eval_string Optionally Prime `eval_string` with a start value.
  # @return [String] The Ruby expression.
  # @example
  #   Pry.new.r(Object.new)
  def r(target=TOPLEVEL_BINDING, eval_string="")
    target = Pry.binding_for(target)
    @suppress_output = false

    val = ""
    loop do
      begin
        # eval_string will probably be mutated by this method
        retrieve_line(eval_string, target)
      rescue CommandError, Slop::InvalidOptionError => e
        output.puts "Error: #{e.message}"
      end

      break if valid_expression?(eval_string)
    end

    @suppress_output = true if eval_string =~ /;\Z/ || eval_string.empty?

    hooks.exec_hook :after_read, eval_string, self
    eval_string
  end

  # Output the result or pass to an exception handler (if result is an exception).
  def show_result(result)
    if last_result_is_exception?
      exception_handler.call output, result, self
    else
      print.call output, result
    end
  rescue RescuableException => e
    # Being uber-paranoid here, given that this exception arose because we couldn't
    # serialize something in the user's program, let's not assume we can serialize
    # the exception either.
    begin
      output.puts "(pry) output error: #{e.inspect}"
    rescue RescuableException => e
      if last_result_is_exception?
        output.puts "(pry) output error: failed to show exception"
      else
        output.puts "(pry) output error: failed to show result"
      end
    end
  end

  def should_force_encoding?(eval_string, val)
    eval_string.empty? && val.respond_to?(:encoding) && val.encoding != eval_string.encoding
  end
  private :should_force_encoding?

  # Read and process a line of input -- check for ^D, determine which prompt to
  # use, rewrite the indentation if `Pry.config.auto_indent` is enabled, and,
  # if the line is a command, process it and alter the eval_string accordingly.
  # This method should not need to be invoked directly.
  #
  # @param [String] eval_string The cumulative lines of input.
  # @param [Binding] target The target of the session.
  # @return [String] The line received.
  def retrieve_line(eval_string, target)
    @indent.reset if eval_string.empty?

    # sometimes colors leak, so we defensively reset here
    reset_char = Pry.color ? "\e[0m" : ""
    current_prompt = select_prompt(eval_string, target)
    indentation = Pry.config.auto_indent ? @indent.indent_level : ''

    val = readline(reset_char + current_prompt + indentation)

    # invoke handler if we receive EOF character (^D)
    if !val
      output.puts ""
      Pry.config.control_d_handler.call(eval_string, self)
      return
    end

    # Change the eval_string into the input encoding (Issue 284)
    # TODO: This wouldn't be necessary if the eval_string was constructed from
    # input strings only.
    if should_force_encoding?(eval_string, val)
      eval_string.force_encoding(val.encoding)
    end

    if Pry.config.auto_indent && !input.is_a?(StringIO)
      original_val = "#{indentation}#{val}"
      indented_val = @indent.indent(val)

      if original_val != indented_val && output.tty? && Pry::Helpers::BaseHelpers.use_ansi_codes? && Pry.config.correct_indent
        output.print @indent.correct_indentation(current_prompt + indented_val, original_val.length - indented_val.length)
      end
    else
      indented_val = val
    end

    if !process_command(val, eval_string, target)
      eval_string << "#{indented_val.rstrip}\n" unless val.empty?
    end
    Pry.history << indented_val unless input.is_a?(StringIO)
  end

  # If the given line is a valid command, process it in the context of the
  # current `eval_string` and context.
  # This method should not need to be invoked directly.
  # @param [String] val The line to process.
  # @param [String] eval_string The cumulative lines of input.
  # @param [Binding] target The target of the Pry session.
  # @return [Boolean] `true` if `val` is a command, `false` otherwise
  def process_command(val, eval_string, target)
    result = @command_processor.process_commands(val, eval_string, target)

    # set a temporary (just so we can inject the value we want into eval_string)
    Thread.current[:__pry_cmd_result__] = result

    # note that `result` wraps the result of command processing; if a
    # command was matched and invoked then `result.command?` returns true,
    # otherwise it returns false.
    if result.command?
      if !result.void_command?
        # the command that was invoked was non-void (had a return value) and so we make
        # the value of the current expression equal to the return value
        # of the command.
        eval_string.replace "Thread.current[:__pry_cmd_result__].retval\n"
      end
      true
    else
      false
    end
  end

  # Run the specified command.
  # @param [String] val The command (and its params) to execute.
  # @param [String] eval_string The current input buffer.
  # @param [Binding] target The binding to use..
  # @return [Pry::CommandContext::VOID_VALUE]
  # @example
  #   pry_instance.run_command("ls -m")
  def run_command(val, eval_string = "", target = binding_stack.last)
    @command_processor.process_commands(val, eval_string, target)
    Pry::CommandContext::VOID_VALUE
  end

  # Set the last result of an eval.
  # This method should not need to be invoked directly.
  # @param [Object] result The result.
  # @param [Binding] target The binding to set `_` on.
  def set_last_result(result, target)
    @last_result_is_exception = false
    @output_array << result

    self.last_result = result
  end

  # Set the last exception for a session.
  # This method should not need to be invoked directly.
  # @param [Exception] ex The exception.
  # @param [Binding] target The binding to set `_ex_` on.
  def set_last_exception(ex, target)
    class << ex
      attr_accessor :file, :line, :bt_index
      def bt_source_location_for(index)
        backtrace[index] =~ /(.*):(\d+)/
        [$1, $2.to_i]
      end
    end

    ex.bt_index = 0
    ex.file, ex.line = ex.bt_source_location_for(0)

    @last_result_is_exception = true
    @output_array << ex

    self.last_exception = ex
  end

  # Update Pry's internal state after evalling code.
  # This method should not need to be invoked directly.
  # @param [String] code The code we just eval'd
  def update_input_history(code)
    # Always push to the @input_array as the @output_array is always pushed to.
    @input_array << code
    if code
      Pry.line_buffer.push(*code.each_line)
      Pry.current_line += code.each_line.count
    end
  end

  # @return [Boolean] True if the last result is an exception that was raised,
  #   as opposed to simply an instance of Exception (like the result of
  #   Exception.new)
  def last_result_is_exception?
    @last_result_is_exception
  end

  # Manage switching of input objects on encountering EOFErrors
  def handle_read_errors
    should_retry = true
    begin
      yield
    rescue EOFError
      if input_stack.empty?
        self.input = Pry.config.input
        if !should_retry
          output.puts "Error: Pry ran out of things to read from! Attempting to break out of REPL."
          throw(:breakout)
        end
        should_retry = false
      else
        self.input = input_stack.pop
      end
      retry
    end
  end

  private :handle_read_errors

  # Returns the next line of input to be used by the pry instance.
  # This method should not need to be invoked directly.
  # @param [String] current_prompt The prompt to use for input.
  # @return [String] The next line of input.
  def readline(current_prompt="> ")
    handle_read_errors do
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

  # Whether the print proc should be invoked.
  # Currently only invoked if the output is not suppressed OR the last result
  # is an exception regardless of suppression.
  # @return [Boolean] Whether the print proc should be invoked.
  def should_print?
    !@suppress_output || last_result_is_exception?
  end

  # Returns the appropriate prompt to use.
  # This method should not need to be invoked directly.
  # @param [String] eval_string The current input buffer.
  # @param [Binding] target The target Binding of the Pry session.
  # @return [String] The prompt.
  def select_prompt(eval_string, target)
    target_self = target.eval('self')

    # If input buffer is empty then use normal prompt
    if eval_string.empty?
      Array(prompt).first.call(target_self, binding_stack.size - 1, self)

    # Otherwise use the wait prompt (indicating multi-line expression)
    else
      Array(prompt).last.call(target_self, binding_stack.size - 1, self)
    end
  end

  # the array that the prompt stack is stored in
  def prompt_stack
    @prompt_stack ||= Array.new
  end
  private :prompt_stack

  # Pushes the current prompt onto a stack that it can be restored from later.
  # Use this if you wish to temporarily change the prompt.
  # @param [Array<Proc>] new_prompt
  # @return [Array<Proc>] new_prompt
  # @example
  #    new_prompt = [ proc { '>' }, proc { '>>' } ]
  #    push_prompt(new_prompt) # => new_prompt
  def push_prompt(new_prompt)
    prompt_stack.push new_prompt
  end

  # Pops the current prompt off of the prompt stack.
  # If the prompt you are popping is the last prompt, it will not be popped.
  # Use this to restore the previous prompt.
  # @return [Array<Proc>] Prompt being popped.
  # @example
  #    prompt1 = [ proc { '>' }, proc { '>>' } ]
  #    prompt2 = [ proc { '$' }, proc { '>' } ]
  #    pry = Pry.new :prompt => prompt1
  #    pry.push_prompt(prompt2)
  #    pry.pop_prompt # => prompt2
  #    pry.pop_prompt # => prompt1
  #    pry.pop_prompt # => prompt1
  def pop_prompt
    prompt_stack.size > 1 ? prompt_stack.pop : prompt
  end

  # Determine if a string of code is a complete Ruby expression.
  # @param [String] code The code to validate.
  # @return [Boolean] Whether or not the code is a complete Ruby expression.
  # @raise [SyntaxError] Any SyntaxError that does not represent incompleteness.
  # @example
  #   valid_expression?("class Hello") #=> false
  #   valid_expression?("class Hello; end") #=> true
  def valid_expression?(str)
    if defined?(Rubinius::Melbourne19) && RUBY_VERSION =~ /^1\.9/
      Rubinius::Melbourne19.parse_string(str, Pry.eval_path)
    elsif defined?(Rubinius::Melbourne)
      Rubinius::Melbourne.parse_string(str, Pry.eval_path)
    else
      catch(:valid) {
        eval("BEGIN{throw :valid}\n#{str}", binding, Pry.eval_path)
      }
    end
    true
  rescue SyntaxError => e
    if incomplete_user_input_exception?(e)
      false
    else
      raise e
    end
  end

  # Check whether the exception indicates that the user should input more.
  #
  # @param [SyntaxError] the exception object that was raised.
  # @param [Array<String>] The stack frame of the function that executed eval.
  # @return [Boolean]
  #
  def incomplete_user_input_exception?(ex)
    case ex.message
    when /unexpected (\$end|end-of-file|END_OF_FILE)/, # mri, jruby, ironruby
        /unterminated (quoted string|string|regexp) meets end of file/, # "quoted string" is ironruby
        /missing 'end' for/, /: expecting '[})\]]'$/, /can't find string ".*" anywhere before EOF/, /expecting keyword_end/ # rbx
      true
    else
      false
    end
  end
end
