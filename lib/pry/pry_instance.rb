require "pry/indent"

##
# Pry is a powerful alternative to the standard IRB shell for Ruby. It
# features syntax highlighting, a flexible plugin architecture, runtime
# invocation and source and documentation browsing.
#
# Pry can be started similar to other command line utilities by simply running
# the following command:
#
#     pry
#
# Once inside Pry you can invoke the help message:
#
#     help
#
# This will show a list of available commands and their usage. For more
# information about Pry you can refer to the following resources:
#
# * http://pry.github.com/
# * https://github.com/pry/pry
# * the IRC channel, which is #pry on the Freenode network
#
class Pry

  attr_accessor :input
  attr_accessor :output
  attr_accessor :commands
  attr_accessor :print
  attr_accessor :exception_handler
  attr_accessor :input_stack
  attr_accessor :quiet
  alias :quiet? :quiet

  attr_accessor :custom_completions

  attr_accessor :binding_stack

  attr_accessor :last_result
  attr_accessor :last_file
  attr_accessor :last_dir

  attr_reader :last_exception

  attr_reader :input_array
  attr_reader :output_array

  attr_accessor :backtrace

  attr_accessor :extra_sticky_locals

  attr_accessor :suppress_output

  # This is exposed via Pry::Command#state.
  attr_reader :command_state

  # Special treatment for hooks as we want to alert people of the
  # changed API
  attr_reader :hooks

  # FIXME:
  # This is a hack to alert people of the new API.
  # @param [Pry::Hooks] v Only accept `Pry::Hooks` now!
  def hooks=(v)
    if v.is_a?(Hash)
      warn "Hash-based hooks are now deprecated! Use a `Pry::Hooks` object instead! http://rubydoc.info/github/pry/pry/master/Pry/Hooks"
      @hooks = Pry::Hooks.from_hash(v)
    else
      @hooks = v
    end
  end

  # Create a new `Pry` object.
  # @param [Hash] options The optional configuration parameters.
  # @option options [#readline] :input The object to use for input.
  # @option options [#puts] :output The object to use for output.
  # @option options [Pry::CommandBase] :commands The object to use for commands.
  # @option options [Hash] :hooks The defined hook Procs
  # @option options [Array<Proc>] :prompt The array of Procs to use for the prompts.
  # @option options [Proc] :print The Proc to use for the 'print'
  # @option options [Boolean] :quiet If true, omit the whereami banner when starting.
  #   component of the REPL. (see print.rb)
  def initialize(options={})
    refresh(options)

    @binding_stack = []
    @indent        = Pry::Indent.new
    @command_state = {}
  end

  # Refresh the Pry instance settings from the Pry class.
  # Allows options to be specified to override settings from Pry class.
  # @param [Hash] options The options to override Pry class settings
  #   for this instance.
  def refresh(options={})
    defaults   = {}
    attributes = [
                   :input, :output, :commands, :print, :quiet,
                   :exception_handler, :hooks, :custom_completions,
                   :prompt, :memory_size, :extra_sticky_locals
                 ]

    attributes.each do |attribute|
      defaults[attribute] = Pry.send attribute
    end

    defaults[:input_stack] = Pry.input_stack.dup

    defaults.merge!(options).each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end

    true
  end

  # The currently active `Binding`.
  # @return [Binding] The currently active `Binding` for the session.
  def current_context
    binding_stack.last
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
    Pry.current[:pry_local] = value.is_a?(Proc) ? value.call : value
    b.eval("#{name} = ::Pry.current[:pry_local]")
  ensure
    Pry.current[:pry_local] = nil
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

  # Inject all the sticky locals into the `target` binding.
  # @param [Binding] target
  def inject_sticky_locals(target)
    sticky_locals.each_pair do |name, value|
      inject_local(name, value, target)
    end
  end

  # Add a sticky local to this Pry instance.
  # A sticky local is a local that persists between all bindings in a session.
  # @param [Symbol] name The name of the sticky local.
  # @yield The block that defines the content of the local. The local
  #   will be refreshed at each tick of the repl loop.
  def add_sticky_local(name, &block)
    sticky_locals[name] = block
  end

  # @return [Hash] The currently defined sticky locals.
  def sticky_locals
    @sticky_locals ||= {
      :_in_   => proc { @input_array },
      :_out_  => proc { @output_array },
      :_pry_  => self,
      :_ex_   => proc { last_exception },
      :_file_ => proc { last_file },
      :_dir_  => proc { last_dir },
      :_      => proc { last_result },
      :__     => proc { @output_array[-2] }
    }.merge(extra_sticky_locals)
  end

  # Initialize the repl session.
  # @param [Binding] target The target binding for the session.
  def repl_prologue(target)
    exec_hook :before_session, output, target, self
    set_last_result(nil, target)

    @input_array << nil # add empty input so _in_ and _out_ match

    binding_stack.push target
  end

  # Clean-up after the repl session.
  # @param [Binding] target The target binding for the session.
  def repl_epilogue(target)
    exec_hook :after_session, output, target, self

    binding_stack.pop
    Pry.save_history if Pry.config.history.should_save
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

    repl_prologue(target)

    break_data = nil
    exception = catch(:raise_up) do
      break_data = catch(:breakout) do
        loop do
          throw(:breakout) if binding_stack.empty?
          rep(binding_stack.last)
        end
      end
      exception = false
    end

    raise exception if exception

    break_data
  ensure
    repl_epilogue(target)
  end

  # Perform a read-eval-print.
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the read-eval-print
  # @example
  #   Pry.new.rep(Object.new)
  def rep(target=TOPLEVEL_BINDING)
    target = Pry.binding_for(target)
    result = re(target)

    Pry.critical_section do
      show_result(result)
    end
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

    # It's not actually redundant to inject them continually as we may have
    # moved into the scope of a new Binding (e.g the user typed `cd`).
    inject_sticky_locals(target)

    code = r(target)

    evaluate_ruby(code, target)
  rescue RescuableException => e
    self.last_exception = e
    e
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

    loop do
      begin
        # eval_string will probably be mutated by this method
        retrieve_line(eval_string, target)
      rescue CommandError, Slop::InvalidOptionError, MethodSource::SourceNotFoundError => e
        Pry.last_internal_error = e
        output.puts "Error: #{e.message}"
      end

      begin
        break if Pry::Code.complete_expression?(eval_string)
      rescue SyntaxError => e
        exception_handler.call(output, e.extend(UserError), self)
        eval_string = ""
      end
    end

    if eval_string =~ /;\Z/ || eval_string.empty? || eval_string =~ /\A *#.*\n\z/
      @suppress_output = true
    end

    exec_hook :after_read, eval_string, self
    eval_string
  end

  def evaluate_ruby(code, target = binding_stack.last)
    target = Pry.binding_for(target)
    inject_sticky_locals(target)
    exec_hook :before_eval, code, self

    result = target.eval(code, Pry.eval_path, Pry.current_line)
    set_last_result(result, target, code)
  ensure
    update_input_history(code)
    exec_hook :after_eval, result, self
  end

  # Output the result or pass to an exception handler (if result is an exception).
  def show_result(result)
    if last_result_is_exception?
      exception_handler.call(output, result, self)
    elsif should_print?
      print.call(output, result)
    else
      # nothin'
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

    current_prompt = select_prompt(eval_string, target)
    completion_proc = Pry.config.completer.build_completion_proc(target, self,
                                                        instance_eval(&custom_completions))

    safe_completion_proc = proc{ |*a| Pry.critical_section{ completion_proc.call(*a) } }

    indentation = Pry.config.auto_indent ? @indent.current_prefix : ''

    begin
      val = readline("#{current_prompt}#{indentation}", safe_completion_proc)

    # Handle <Ctrl+C> like Bash, empty the current input buffer but do not quit.
    # This is only for ruby-1.9; other versions of ruby do not let you send Interrupt
    # from within Readline.
    rescue Interrupt
      output.puts ""
      eval_string.replace("")
      return
    end

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

      if output.tty? && Pry::Helpers::BaseHelpers.use_ansi_codes? && Pry.config.correct_indent
        output.print @indent.correct_indentation(current_prompt, indented_val, original_val.length - indented_val.length)
        output.flush
      end
    else
      indented_val = val
    end

    # Check this before processing the line, because a command might change
    # Pry's input.
    interactive = !input.is_a?(StringIO)

    begin
      if !process_command(val, eval_string, target)
        eval_string << "#{indented_val.chomp}\n" unless val.empty?
      end
    ensure
      Pry.history << indented_val if interactive
    end
  end

  # If the given line is a valid command, process it in the context of the
  # current `eval_string` and context.
  # This method should not need to be invoked directly.
  # @param [String] val The line to process.
  # @param [String] eval_string The cumulative lines of input.
  # @param [Binding] target The target of the Pry session.
  # @return [Boolean] `true` if `val` is a command, `false` otherwise
  def process_command(val, eval_string = '', target = binding_stack.last)
    val = val.chomp
    result = commands.process_line(val, {
      :target => target,
      :output => output,
      :eval_string => eval_string,
      :pry_instance => self
    })

    # set a temporary (just so we can inject the value we want into eval_string)
    Pry.current[:pry_cmd_result] = result

    # note that `result` wraps the result of command processing; if a
    # command was matched and invoked then `result.command?` returns true,
    # otherwise it returns false.
    if result.command?
      if !result.void_command?
        # the command that was invoked was non-void (had a return value) and so we make
        # the value of the current expression equal to the return value
        # of the command.
        eval_string.replace "::Pry.current[:pry_cmd_result].retval\n"
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
  # @return [Pry::Command::VOID_VALUE]
  # @example
  #   pry_instance.run_command("ls -m")
  def run_command(val, eval_string = "", target = binding_stack.last)
    commands.process_line(val,
      :eval_string => eval_string,
      :target => target,
      :pry_instance => self,
      :output => output
    )
    Pry::Command::VOID_VALUE
  end

  # Execute the specified hook.
  # @param [Symbol] name The hook name to execute
  # @param [*Object] args The arguments to pass to the hook
  # @return [Object, Exception] The return value of the hook or the exception raised
  #
  # If executing a hook raises an exception, we log that and then continue sucessfully.
  # To debug such errors, use the global variable $pry_hook_error, which is set as a
  # result.
  def exec_hook(name, *args, &block)
    e_before = hooks.errors.size
    hooks.exec_hook(name, *args, &block).tap do
      hooks.errors[e_before..-1].each do |e|
        output.puts "#{name} hook failed: #{e.class}: #{e.message}"
        output.puts "#{e.backtrace.first}"
        output.puts "(see _pry_.hooks.errors to debug)"
      end
    end
  end

  # Set the last result of an eval.
  # This method should not need to be invoked directly.
  # @param [Object] result The result.
  # @param [Binding] target The binding to set `_` on.
  # @param [String] code The code that was run.
  def set_last_result(result, target, code="")
    @last_result_is_exception = false
    @output_array << result

    self.last_result = result unless code =~ /\A\s*\z/
  end

  # Set the last exception for a session.
  # @param [Exception] ex
  def last_exception=(ex)
    class << ex
      attr_accessor :file, :line, :bt_index
      def bt_source_location_for(index)
        backtrace[index] =~ /(.*):(\d+)/
        [$1, $2.to_i]
      end

      def inc_bt_index
        @bt_index = (@bt_index + 1) % backtrace.size
      end
    end

    ex.bt_index = 0
    ex.file, ex.line = ex.bt_source_location_for(0)

    @last_result_is_exception = true
    @output_array << ex
    @last_exception = ex
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
    exception_count = 0
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

    # Interrupts are handled in r() because they need to tweak eval_string
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
  private :handle_read_errors

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
        if !$stdout.tty? && $stdin.tty? && !Pry::Helpers::BaseHelpers.windows?
          Readline.output = File.open('/dev/tty', 'w')
        end
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
  # Currently only invoked if the output is not suppressed.
  # @return [Boolean] Whether the print proc should be invoked.
  def should_print?
    !@suppress_output
  end

  # Returns the appropriate prompt to use.
  # This method should not need to be invoked directly.
  # @param [String] eval_string The current input buffer.
  # @param [Binding] target The target Binding of the Pry session.
  # @return [String] The prompt.
  def select_prompt(eval_string, target)
    target_self = target.eval('self')

    open_token = @indent.open_delimiters.any? ? @indent.open_delimiters.last :
      @indent.stack.last

    c = OpenStruct.new(
                       :object         => target_self,
                       :nesting_level  => binding_stack.size - 1,
                       :open_token     => open_token,
                       :session_line   => Pry.history.session_line_count + 1,
                       :history_line   => Pry.history.history_line_count + 1,
                       :expr_number    => input_array.count,
                       :_pry_          => self,
                       :binding_stack  => binding_stack,
                       :input_array    => input_array,
                       :eval_string    => eval_string,
                       :cont           => !eval_string.empty?)

    Pry.critical_section do
      # If input buffer is empty then use normal prompt
      if eval_string.empty?
        generate_prompt(Array(prompt).first, c)

      # Otherwise use the wait prompt (indicating multi-line expression)
      else
        generate_prompt(Array(prompt).last, c)
      end
    end
  end

  def generate_prompt(prompt_proc, conf)
    if prompt_proc.arity == 1
      prompt_proc.call(conf)
    else
      prompt_proc.call(conf.object, conf.nesting_level, conf._pry_)
    end
  end
  private :generate_prompt

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

  # Raise an exception out of Pry.
  #
  # See Kernel#raise for documentation of parameters.
  # See rb_make_exception for the inbuilt implementation.
  #
  # This is necessary so that the raise-up command can tell the
  # difference between an exception the user has decided to raise,
  # and a mistake in specifying that exception.
  #
  # (i.e. raise-up RunThymeError.new should not be the same as
  #  raise-up NameError, "unititialized constant RunThymeError")
  #
  def raise_up_common(force, *args)
    exception = if args == []
                  last_exception || RuntimeError.new
                elsif args.length == 1 && args.first.is_a?(String)
                  RuntimeError.new(args.first)
                elsif args.length > 3
                  raise ArgumentError, "wrong number of arguments"
                elsif !args.first.respond_to?(:exception)
                  raise TypeError, "exception class/object expected"
                elsif args.length === 1
                  args.first.exception
                else
                  args.first.exception(args[1])
                end

    raise TypeError, "exception object expected" unless exception.is_a? Exception

    exception.set_backtrace(args.length === 3 ? args[2] : caller(1))

    if force || binding_stack.one?
      binding_stack.clear
      throw :raise_up, exception
    else
      binding_stack.pop
      raise exception
    end
  end
  def raise_up(*args); raise_up_common(false, *args); end
  def raise_up!(*args); raise_up_common(true, *args); end
end
