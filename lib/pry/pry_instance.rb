direc = File.dirname(__FILE__)

require "#{direc}/command_processor.rb"

class Pry

  # The list of configuration options.
  CONFIG_OPTIONS = [:input, :output, :commands, :print,
                    :exception_handler, :prompt, :hooks,
                    :custom_completions]

  attr_accessor *CONFIG_OPTIONS

  # Returns the target binding for the session. Note that altering this
  # attribute will not change the target binding.
  # @return [Binding] The target object for the session
  attr_accessor :session_target

  # Create a new `Pry` object.
  # @param [Hash] options The optional configuration parameters.
  # @option options [#readline] :input The object to use for input.
  # @option options [#puts] :output The object to use for output.
  # @option options [Pry::CommandBase] :commands The object to use for commands. (see commands.rb)
  # @option options [Hash] :hooks The defined hook Procs (see hooks.rb)
  # @option options [Array<Proc>] :default_prompt The array of Procs to use for the prompts. (see prompts.rb)
  # @option options [Proc] :print The Proc to use for the 'print'
  #   component of the REPL. (see print.rb)
  def initialize(options={})

    default_options = {}
    CONFIG_OPTIONS.each { |v| default_options[v] = Pry.send(v) }
    default_options.merge!(options)

    CONFIG_OPTIONS.each do |key|
      instance_variable_set("@#{key}", default_options[key])
    end

    @command_processor = CommandProcessor.new(self)
  end

  # Get nesting data.
  # This method should not need to be accessed directly.
  # @return [Array] The unparsed nesting information.
  def nesting
    self.class.nesting
  end

  # Set nesting data.
  # This method should not need to be accessed directly.
  # @param v nesting data.
  def nesting=(v)
    self.class.nesting = v
  end

  # Return parent of current Pry session.
  # @return [Pry] The parent of the current Pry session.
  def parent
    idx = Pry.sessions.index(self)

    if idx > 0
      Pry.sessions[idx - 1]
    else
      nil
    end
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
    target.eval("_pry_ = ::Pry.active_instance")
    target.eval("_ = ::Pry.last_result")
    self.session_target = target
  end

  # Clean-up after the repl session.
  # @param [Binding] target The target binding for the session.
  # @return [Object] The return value of the repl session (if one exists).
  def repl_epilogue(target, nesting_level, break_data)
    nesting.pop
    exec_hook :after_session, output, target

    # If break_data is an array, then the last element is the return value
    break_level, return_value = Array(break_data)

    # keep throwing until we reach the desired nesting level
    if nesting_level != break_level
      throw :breakout, break_data
    end

    return_value
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

    # cannot rely on nesting.level as
    # nesting.level changes with new sessions
    nesting_level = nesting.size

    break_data = catch(:breakout) do
      nesting.push [nesting.size, target_self, self]
      loop do
        rep(target)
      end
    end

    return_value = repl_epilogue(target, nesting_level, break_data)

    # if one was provided, return the return value
    return return_value if return_value

    # otherwise return the target_self
    target_self
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
    target.eval("_pry_ = ::Pry.active_instance")

    @last_result_is_exception = false

    # eval the expression and save to last_result
    # Do not want __FILE__, __LINE__ here because we need to distinguish
    # (eval) methods for show-method and friends.
    # This also sets the `_` local for the session.
    set_last_result(target.eval(r(target)), target)
  rescue SystemExit => e
    exit
  rescue Exception => e
    @last_result_is_exception = true
    set_last_exception(e, target)
  end

  # Perform a read.
  # If no parameter is given, default to top-level (main).
  # This is a multi-line read; so the read continues until a valid
  # Ruby expression is received.
  # Pry commands are also accepted here and operate on the target.
  # @param [Object, Binding] target The receiver of the read.
  # @return [String] The Ruby expression.
  # @example
  #   Pry.new.r(Object.new)
  def r(target=TOPLEVEL_BINDING)
    target = Pry.binding_for(target)
    @suppress_output = false
    eval_string = ""

    val = ""
    loop do
      val = retrieve_line(eval_string, target)
      process_line(val, eval_string, target)
      break if valid_expression?(eval_string)
    end

    @suppress_output = true if eval_string =~ /;\Z/ || null_input?(val)

    eval_string
  end

  # FIXME should delete this method? it's exposing an implementation detail!
  def show_result(result)
    if last_result_is_exception?
      exception_handler.call output, result
    else
      print.call output, result
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

    # exit session if we receive EOF character
    if !val
      output.puts
      throw(:breakout, nesting.level)
    end

    val
  end

  # Process the line received.
  # This method should not need to be invoked directly.
  # @param [String] val The line to process.
  # @param [String] eval_string The cumulative lines of input.
  # @target [Binding] target The target of the Pry session.
  def process_line(val, eval_string, target)
    val.rstrip!
    Pry.cmd_ret_value = @command_processor.process_commands(val, eval_string, target)

    if Pry.cmd_ret_value
      eval_string << "Pry.cmd_ret_value\n"
    else
      eval_string << "#{val}\n" if !val.empty?
    end
  end

  # Set the last result of an eval.
  # This method should not need to be invoked directly.
  # @param [Object] result The result.
  # @param [Binding] target The binding to set `_` on.
  def set_last_result(result, target)
    Pry.last_result = result
    target.eval("_ = ::Pry.last_result")
  end

  # Set the last exception for a session.
  # This method should not need to be invoked directly.
  # @param [Exception] ex The exception.
  # @param [Binding] target The binding to set `_ex_` on.
  def set_last_exception(ex, target)
    Pry.last_exception = ex
    target.eval("_ex_ = ::Pry.last_exception")
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
        self.input = Readline
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
      Array(prompt).first.call(target_self, nesting.level)
    else
      Array(prompt).last.call(target_self, nesting.level)
    end
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
    rescue Racc::ParseError, SyntaxError
      false
    else
      true
    end
  end
end
