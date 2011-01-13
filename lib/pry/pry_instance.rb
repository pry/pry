require 'readline'

class Pry

  # The list of configuration options.
  ConfigOptions = [:input, :output, :commands, :print,
                   :prompt, :hooks]

  attr_accessor *ConfigOptions

  # Create a new `Pry` object.
  # @param [Hash] options The optional configuration parameters.
  # @option options [#readline] :input The object to use for input. (see input.rb)
  # @option options [#puts] :output The object to use for output. (see output.rb)
  # @option options [Pry::CommandBase] :commands The object to use for
  #   commands. (see commands.rb)
  # @option options [Hash] :hooks The defined hook Procs (see hooks.rb)
  # @option options [Array<Proc>] :default_prompt The array of Procs
  #   to use for the prompts. (see prompts.rb)
  # @option options [Proc] :print The Proc to use for the 'print'
  #   component of the REPL. (see print.rb)
  def initialize(options={})

    h = {}
    ConfigOptions.each { |v| h[v] = Pry.send(v) }
    default_options = h
    default_options.merge!(options)

    ConfigOptions.each do |key|
      instance_variable_set("@#{key}", default_options[key])
    end
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

  # Start a read-eval-print-loop.
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the Pry session
  # @return [Object] The target of the Pry session
  # @example
  #   Pry.new.repl(Object.new)
  def repl(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    target_self = target.eval('self')

    exec_hook :before_session, output, target_self

    # cannot rely on nesting.level as
    # nesting.level changes with new sessions
    nesting_level = nesting.size

    Pry.active_instance = self

    # Make sure special locals exist
    target.eval("_pry_ = Pry.active_instance")
    target.eval("_ = Pry.last_result")

    break_level = catch(:breakout) do
      nesting.push [nesting.size, target_self, self]
      loop do
        rep(target)
      end
    end

    nesting.pop

    exec_hook :after_session, output, target_self

    # keep throwing until we reach the desired nesting level
    if nesting_level != break_level
      throw :breakout, break_level
    end

    target_self
  end

  # Perform a read-eval-print.
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the read-eval-print
  # @example
  #   Pry.new.rep(Object.new)
  def rep(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    print.call output, re(target)
  end

  # Perform a read-eval
  # If no parameter is given, default to top-level (main).
  # @param [Object, Binding] target The receiver of the read-eval-print
  # @return [Object] The result of the eval or an `Exception` object in case of error.
  # @example
  #   Pry.new.re(Object.new)
  def re(target=TOPLEVEL_BINDING)
    target = binding_for(target)

    if input == Readline
      Readline.completion_proc = Pry::InputCompleter.build_completion_proc(target, Pry.commands.command_info.keys.flatten)
    end

    # eval the expression and save to last_result
    Pry.last_result = target.eval r(target)

    # save the pry instance to active_instance
    Pry.active_instance = self

    # define locals _pry_ and _ (active instance and last expression)
    target.eval("_pry_ = Pry.active_instance")
    target.eval("_ = Pry.last_result")
  rescue SystemExit => e
    exit
  rescue Exception => e
    e
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
    target = binding_for(target)
    eval_string = ""

    loop do
      current_prompt = select_prompt(eval_string.empty?, target.eval('self'))

      val = readline(current_prompt)
      val.chomp!

      process_commands(val, eval_string, target)
      eval_string << "#{val}\n"

      break eval_string if valid_expression?(eval_string)
    end
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

    pattern, action = commands.commands.find { |k, v| Array(k).any? { |a| a === val } }

    if pattern
      last_match = Regexp.last_match

      options = {
        :captures => last_match ? last_match.captures : nil,
        :eval_string => eval_string,
        :target => target,
        :val => val,
        :nesting => nesting,
        :output => output,
        :command_info => commands.command_info
      }

      action.call(options)
      val.clear
    end
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
      if input.method(:readline).arity == 1
        input.readline(current_prompt)
      else
        input.readline
      end
    end
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

  if RUBY_VERSION =~ /1.9/
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

  # Return a `Binding` object for `target` or return `target` if it is
  # already a `Binding`.
  # In the case where `target` is top-level then return `TOPLEVEL_BINDING`
  # @param [Object] target The object to get a `Binding` object for.
  # @return [Binding] The `Binding` object.
  def binding_for(target)
    if target.is_a?(Binding)
      target
    else
      if target == TOPLEVEL_BINDING.eval('self')
        TOPLEVEL_BINDING
      else
        target.__binding__
      end
    end
  end
end
