require 'ostruct'

class Pry
  class Config < OpenStruct

    # Get/Set the object to use for input by default by all Pry instances.
    # Pry.config.input is an option determining the input object - the object from
    # which Pry retrieves its lines of input. Pry accepts any object that
    # implements the readline method.  This includes IO objects, StringIO,
    # Readline, File and custom objects. It can also be a Proc which returns an
    # object implementing the readline method.
    # @return [#readline] The object to use for input by default by all
    #   Pry instances.
    # @example
    #   Pry.config.input = StringIO.new("@x = 10\nexit")
    def input
      @reified_input ||=
        if @input.respond_to?(:call)
          @input.call
        else
          @input
        end
    end

    def input=(input)
      @reified_input = nil
      @input = input
    end

    # Get/Set the object to use for output by default by all Pry instances.
    # Pry.config.output is an option determining the output object - the object to which
    # Pry writes its output. Pry accepts any object that implements the puts method. This
    # includes IO objects, StringIO, File and custom objects.
    # @return [#puts] The object to use for output by default by all
    #   Pry instances.
    # @example
    #   Pry.config.output = StringIO.new
    attr_accessor :output

    # Get/Set the object to use for commands by default by all Pry instances.
    # @return [Pry::CommandBase] The object to use for commands by default by all
    #   Pry instances.
    # @example
    #   Pry.config.commands = Pry::CommandSet.new do
    #               import_from Pry::Commands, "ls"
    #
    #                 command "greet" do |name|
    #                 output.puts "hello #{name}"
    #               end
    #             end
    attr_accessor :commands

    # Get/Set the Proc to use for printing by default by all Pry
    # instances.
    # Two parameters are passed to the print Proc: these are (1) the
    # output object for the current session and (2) the expression value to print. It is important
    # that you write to the output object instead of just stdout so that all Pry output can be redirected if necessary.
    # This is the 'print' component of the REPL.
    # @return [Proc] The Proc to use for printing by default by all
    #   Pry instances.
    # @example
    #   Pry.config.print = proc { |output, value| output.puts "=> #{value.inspect}" }
    attr_accessor :print

    # Pry.config.exception_handler is an option determining the exception handler object - the
    # Proc responsible for dealing with exceptions raised by user input to the REPL.
    # Three parameters are passed to the exception handler Proc: these
    # are (1) the output object for the current session, (2) the
    # exception object that was raised inside the Pry session, and (3)
    # a reference to the associated Pry instance.
    # @return [Proc] The Proc to use for printing exceptions by default by all
    #   Pry instances.
    # @example
    #   Pry.config.exception_handler = proc do |output, exception, _|
    #     output.puts "#{exception.class}: #{exception.message}"
    #     output.puts "from #{exception.backtrace.first}"
    #   end
    attr_accessor :exception_handler

    # @return [Array] The classes of exception that will not be caught by Pry.
    # @example
    #   Pry.config.exception_whitelist = [SystemExit, SignalException]
    attr_accessor :exception_whitelist

    # @return [Fixnum] The number of lines of context to show before and after
    #   exceptions, etc.
    # @example
    #   Pry.config.default_window_size = 10
    attr_accessor :default_window_size

    # Get/Set the `Pry::Hooks` instance that defines Pry hooks used by default by all Pry
    # instances.
    # @return [Pry::Hooks] The hooks used by default by all Pry instances.
    # @example
    #   Pry.config.hooks = Pry::Hooks.new.add_hook(:before_session,
    #   :default) {  |output, target, _pry_| output.puts "Good morning!" }
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

    # Get/Set the stack of input objects that a Pry instance switches
    # to when its current input object encounters EOF.
    # @return [Array] The array of input objects.
    # @example
    #   Pry.config.input_stack = [StringIO.new("puts 'hello world'\nexit")]
    attr_accessor :input_stack

    # Get the array of Procs (or single Proc) to be used for the prompts by default by
    # all Pry instances.
    # Three parameters are passed into the prompt procs, (1) the
    # object that is the target of the session, (2) the current
    # nesting level, and (3) a reference to the associated Pry instance. These objects can be used in the prompt, if desired.
    # @return [Array<Proc>, Proc] The array of Procs to be used for the
    #   prompts by default by all Pry instances.
    # @example
    #   Pry.config.prompt = proc { |obj, nest_level, _pry_| "#{obj}:#{nest_level}> " }
    attr_accessor :prompt

    # The display name that is part of the prompt.  Default is 'pry'. 
    # You can set your own name so you can identify which project your current pry session
    # is using.  This is useful if you have a local pryrc file in a Rails project for example.
    # @return [String]
    # @example 
    #   Pry.config.prompt_name = 'my_rails_project'
    attr_accessor :prompt_name
    
    # The default editor to use. Defaults to $VISUAL, $EDITOR, or a sensible fallback
    # for the platform.
    # If `editor` is a String then that string is used as the shell
    # command to invoke the editor. If `editor` is callable (e.g a
    # Proc) then `file`, `line`, and `reloading` are passed in as parameters and the
    # return value of that callable invocation is used as the exact
    # shell command to invoke the editor. `reloading` indicates whether Pry will be
    # reloading code after the shell command returns. Any or all of these parameters
    # can be omitted from the callable's signature.
    # @example String
    #   Pry.config.editor = "emacsclient"
    # @example Callable
    #   Pry.config.editor = proc { |file, line| "emacsclient #{file} +#{line}" }
    # @example Callable waiting only if reloading
    #   Pry.config.editor = proc { |file, line, reloading| "subl #{'--wait' if reloading} #{file}:#{line}" }
    # @return [String, #call]
    attr_accessor :editor

    # A string that must precede all Pry commands (e.g., if command_prefix is
    # set to "%", the "cd" command must be invoked as "%cd").
    # @return [String]
    attr_accessor :command_prefix

    # @return [Boolean] Toggle Pry color on and off.
    attr_accessor :color

    # @return [Boolean] Toggle paging on and off.
    attr_accessor :pager

    # Determines whether the rc file (~/.pryrc) should be loaded.
    # @return [Boolean]
    attr_accessor :should_load_rc

    # Determines whether the local rc file (./.pryrc) should be loaded.
    # @return [Boolean]
    attr_accessor :should_load_local_rc

    # Determines whether plugins should be loaded.
    # @return [Boolean]
    attr_accessor :should_load_plugins

    # Determines whether to load files specified with the -r flag.
    # @return [Boolean]
    attr_accessor :should_load_requires

    # Determines whether to disable edit-method's auto-reloading behavior.
    # @return [Boolean]
    attr_accessor :disable_auto_reload

    # Determines whether Pry should trap SIGINT and cause it to raise an
    # Interrupt exception. This is only useful on jruby, MRI does this
    # for us.
    # @return [Boolean]
    attr_accessor :should_trap_interrupts

    # Config option for history.
    # sub-options include history.file, history.load, and history.save
    # history.file is the file to save/load history to, e.g
    # Pry.config.history.file = "~/.pry_history".
    # history.should_load is a boolean that determines whether history will be
    # loaded from history.file at session start.
    # history.should_save is a boolean that determines whether history will be
    # saved to history.file at session end.
    # @return [OpenStruct]
    attr_accessor :history

    # Config option for plugins:
    # sub-options include:
    # `plugins.strict_loading` (Boolean) which toggles whether referring to a non-existent plugin should raise an exception (defaults to `false`)
    # @return [OpenStruct]
    attr_accessor :plugins

    # @return [Array<String>] Ruby files to be required after loading any plugins.
    attr_accessor :requires

    # @return [Integer] Amount of results that will be stored into out
    attr_accessor :memory_size

    # @return [Proc] The proc that manages ^D presses in the REPL.
    #   The proc is passed the current eval_string and the current pry instance.
    attr_accessor :control_d_handler

    # @return [Proc] The proc that runs system commands
    #   The proc is passed the pry output object, the command string
    #   to eval, and a reference to the pry instance
    attr_accessor :system

    # @return [Boolean] Whether or not code should be indented
    #  using Pry::Indent.
    attr_accessor :auto_indent

    # @return [Boolean] Whether or not indentation should be corrected
    #   after hitting enter. This feature is not supported by all terminals.
    attr_accessor :correct_indent

    # @return [Boolean] Whether or not a warning will be displayed when
    #   a command name collides with a method/local in the current context.
    attr_accessor :collision_warning


    # Config option for gist.
    # sub-options include `gist.inspecter`,
    # `gist.inspecter` is a callable that defines how the expression output
    # will be displayed when using the `gist -i` command.
    # @example Pretty inspect output
    #   Pry.config.gist.inspecter = proc { |v| v.pretty_inspect }
    # @example Regular inspect
    #   Pry.config.gist.inspecter = proc &:inspect
    # @return [OpenStruct]
    attr_accessor :gist

    # @return [Hash] Additional sticky locals (to the standard ones) to use in Pry sessions.
    # @example Inject `random_number` sticky local into Pry session
    #   Pry.config.extra_sticky_locals = { :random_number => proc {
    #   rand(10) } }
    attr_accessor :extra_sticky_locals

    # @return [#build_completion_proc] A completer to use.
    attr_accessor :completer
  end
end

