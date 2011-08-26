require "pry/command_processor.rb"

class Pry

  attr_accessor :input
  attr_accessor :output
  attr_accessor :commands
  attr_accessor :print
  attr_accessor :exception_handler
  attr_accessor :hooks
  attr_accessor :custom_completions

  attr_accessor :binding_stack

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
                   :prompt, :memory_size
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

  # @return [Integer] The maximum amount of objects remembered by the inp and
  #   out arrays. Defaults to 100.
  def memory_size
    @output_array.max_size
  end

  def memory_size=(size)
    @input_array  = Pry::HistoryArray.new(size)
    @output_array = Pry::HistoryArray.new(size)
  end

  # Execute the hook `hook_name`, if it is defined.
  # @param [Symbol] hook_name The hook to execute
  # @param [Array] args The arguments to pass to the hook.
  def exec_hook(hook_name, *args, &block)
    hooks[hook_name].call(*args, &block) if hooks[hook_name]
  end

  # Initialize the repl session.
  # @param [Binding] target The target binding for the session.
  def repl_prologue(target)
    exec_hook :before_session, output, target
    Pry.active_instance = self

    # Make sure special locals exist
    target.eval("inp  = ::Pry.active_instance.instance_eval { @input_array }")
    target.eval("out = ::Pry.active_instance.instance_eval { @output_array }")

    set_active_instance(target)
    @input_array << nil # add empty input so inp and out match
    set_last_result(Pry.last_result, target)

    Pry.active_sessions += 1
    binding_stack.push target
  end

  # Clean-up after the repl session.
  # @param [Binding] target The target binding for the session.
  # @return [Object] The return value of the repl session (if one exists).
  def repl_epilogue(target, break_data)
    exec_hook :after_session, output, target

    Pry.active_sessions -= 1
    binding_stack.pop
    Pry.save_history if Pry.config.history.should_save && Pry.active_sessions == 0
    break_data
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

    return_value = repl_epilogue(target, break_data)
    return_value || target_self
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

    if input == Readline
      # Readline tab completion
      Readline.completion_proc = Pry::InputCompleter.build_completion_proc target, instance_eval(&custom_completions)
    end

    # save the pry instance to active_instance
    Pry.active_instance = self

    target.eval("inp = ::Pry.active_instance.instance_eval { @input_array }")
    target.eval("out = ::Pry.active_instance.instance_eval { @output_array }")

    set_active_instance(target)

    code = r(target)

    res = set_last_result(target.eval(code, Pry.eval_path, Pry.current_line), target)
    res
  rescue SystemExit => e
    exit
  rescue Exception => e
    set_last_exception(e, target)
  ensure
    update_input_history(code)
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
      val = retrieve_line(eval_string, target)
      process_line(val, eval_string, target)

      break if valid_expression?(eval_string)
    end

    @suppress_output = true if eval_string =~ /;\Z/ || null_input?(val)

    eval_string
  end

  # Output the result or pass to an exception handler (if result is an exception).
  def show_result(result)
    if last_result_is_exception?
      exception_handler.call output, result
    else
      print.call output, result
    end
  rescue Exception => e
    # Being uber-paranoid here, given that this exception arose because we couldn't
    # serialize something in the user's program, let's not assume we can serialize
    # the exception either.
    begin
      output.puts "output error: #{e.inspect}"
    rescue Exception => e
      if last_result_is_exception?
        output.puts "output error: failed to show exception"
      else
        output.puts "output error: failed to show result"
      end
    end
  end

  # Returns true if input is "" and a command is not returning a
  # value.
  # @param [String] val The input string.
  # @return [Boolean] Whether the input is null.
  def null_input?(val)
    val.empty? && !Pry.cmd_ret_value
  end

  # Read a line of input and check for ^d, also determine prompt to use.
  # This method should not need to be invoked directly.
  # @param [String] eval_string The cumulative lines of input.
  # @param [Binding] target The target of the session.
  # @return [String] The line received.
  def retrieve_line(eval_string, target)
    current_prompt = select_prompt(eval_string.empty?, target.eval('self'))
    val = readline(current_prompt)

    # exit session if we receive EOF character (^D)
    if !val
      output.puts
      if binding_stack.one?
        # ^D at top-level breaks out of loop
        binding_stack.clear
        throw(:breakout)
      else
        # otherwise just pops a binding
        binding_stack.pop
        val = ""
      end
    end

    val
  end

  # Process the line received.
  # This method should not need to be invoked directly.
  # @param [String] val The line to process.
  # @param [String] eval_string The cumulative lines of input.
  # @param [Binding] target The target of the Pry session.
  def process_line(val, eval_string, target)
    Pry.cmd_ret_value = @command_processor.process_commands(val, eval_string, target)

    if Pry.cmd_ret_value
      eval_string << "Pry.cmd_ret_value\n"
    else
      # only commands (with no ret_value) should have an empty `val` so this ignores their result
      eval_string << "#{val.rstrip}\n" if !val.empty?
    end
  end

  # Set the last result of an eval.
  # This method should not need to be invoked directly.
  # @param [Object] result The result.
  # @param [Binding] target The binding to set `_` on.
  def set_last_result(result, target)
    @last_result_is_exception = false
    @output_array << result

    Pry.last_result = result
    target.eval("_ = ::Pry.last_result")
  end

  # Set the last exception for a session.
  # This method should not need to be invoked directly.
  # @param [Exception] ex The exception.
  # @param [Binding] target The binding to set `_ex_` on.
  def set_last_exception(ex, target)
    class << ex
      attr_accessor :file, :line
    end

    ex.backtrace.first =~ /(.*):(\d+)/
    ex.file, ex.line = $1, $2.to_i

    @last_result_is_exception = true
    @output_array << ex

    Pry.last_exception = ex
    target.eval("_ex_ = ::Pry.last_exception")
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
    if Readline::HISTORY.size > 0

      # all this fluff is to get around annoying bug in libedit on
      # ruby 1.8.7
      final_index = -1
      begin
        Readline::HISTORY[-1]
      rescue IndexError
        final_index = -2
      end
      last = Readline::HISTORY[final_index].strip
      prev = Readline::HISTORY.size > 1 ? Readline::HISTORY[final_index - 1].strip : ''
      Readline::HISTORY.pop if last && (last.empty? || last == prev)
    end
  end

  # Set the active instance for a session.
  # This method should not need to be invoked directly.
  # @param [Binding] target The binding to set `_ex_` on.
  def set_active_instance(target)
    Pry.active_instance = self
    target.eval("_pry_ = ::Pry.active_instance")
  end

  # @return [Boolean] True if the last result is an exception that was raised,
  #   as opposed to simply an instance of Exception (like the result of
  #   Exception.new)
  def last_result_is_exception?
    @last_result_is_exception
  end

  # Returns the next line of input to be used by the pry instance.
  # This method should not need to be invoked directly.
  # @param [String] current_prompt The prompt to use for input.
  # @return [String] The next line of input.
  def readline(current_prompt="> ")

    if input == Readline

      # Readline must be treated differently
      # as it has a second parameter.
      input.readline(current_prompt, true)
    else
      begin
        if input.method(:readline).arity == 1
          input.readline(current_prompt)
        else
          input.readline
        end

      rescue EOFError
        self.input = Pry.input
        ""
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
  # @param [Boolean] first_line Whether this is the first line of input
  #   (and not multi-line input).
  # @param [Object] target_self The receiver of the Pry session.
  # @return [String] The prompt.
  def select_prompt(first_line, target_self)

    if first_line
      Array(prompt).first.call(target_self, binding_stack.size - 1)
    else
      Array(prompt).last.call(target_self, binding_stack.size - 1)
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

  if RUBY_VERSION =~ /1.9/ && RUBY_ENGINE == "ruby"
    require 'ripper'

    # Determine if a string of code is a valid Ruby expression.
    # Ruby 1.9 uses Ripper, Ruby 1.8 uses RubyParser.
    # @param [String] code The code to validate.
    # @return [Boolean] Whether or not the code is a valid Ruby expression.
    # @example
    #   valid_expression?("class Hello") #=> false
    #   valid_expression?("class Hello; end") #=> true
    def valid_expression?(code)
      !!Ripper::SexpBuilder.new(code).parse
    end

  else
    require 'ruby_parser'

    # Determine if a string of code is a valid Ruby expression.
    # Ruby 1.9 uses Ripper, Ruby 1.8 uses RubyParser.
    # @param [String] code The code to validate.
    # @return [Boolean] Whether or not the code is a valid Ruby expression.
    # @example
    #   valid_expression?("class Hello") #=> false
    #   valid_expression?("class Hello; end") #=> true
    def valid_expression?(code)
      RubyParser.new.parse(code)
      true
    rescue Racc::ParseError, SyntaxError
      false
    end
  end
end
