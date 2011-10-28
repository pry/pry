require 'ostruct'

class Pry
  class Config < OpenStruct

    # Get/Set the object to use for input by default by all Pry instances.
    # @return [#readline] The object to use for input by default by all
    #   Pry instances.
    attr_accessor :input

    # Get/Set the object to use for output by default by all Pry instances.
    # @return [#puts] The object to use for output by default by all
    #   Pry instances.
    attr_accessor :output

    # Get/Set the object to use for commands by default by all Pry instances.
    # @return [Pry::CommandBase] The object to use for commands by default by all
    #   Pry instances.
    attr_accessor :commands

    # Get/Set the Proc to use for printing by default by all Pry
    # instances.
    # This is the 'print' component of the REPL.
    # @return [Proc] The Proc to use for printing by default by all
    #   Pry instances.
    attr_accessor :print

    # @return [Proc] The Proc to use for printing exceptions by default by all
    #   Pry instances.
    attr_accessor :exception_handler

    # @return [Array] The classes of exception that will not be caught by Pry.
    attr_accessor :exception_whitelist

    # @return [Fixnum] The number of lines of context to show before and after
    # the exception when using cat --ex.
    attr_accessor :exception_window_size

    # Get/Set the Hash that defines Pry hooks used by default by all Pry
    # instances.
    # @return [Hash] The hooks used by default by all Pry instances.
    # @example
    #   Pry.hooks :before_session => proc { puts "hello" },
    #     :after_session => proc { puts "goodbye" }
    attr_accessor :hooks

    # Get/Set the stack of input objects that a Pry instance switches
    # to when its current input object encounters EOF.
    # @return [Array] The array of input objects.
    # @example
    #   Pry.config.input_stack = [StringIO.new("puts 'hello world'\nexit")]
    attr_accessor :input_stack

    # Get the array of Procs to be used for the prompts by default by
    # all Pry instances.
    # @return [Array<Proc>] The array of Procs to be used for the
    #   prompts by default by all Pry instances.
    attr_accessor :prompt

    # The default editor to use. Defaults to $EDITOR or nano if
    # $EDITOR is not defined.
    # If `editor` is a String then that string is used as the shell
    # command to invoke the editor. If `editor` is callable (e.g a
    # Proc) then `file` and `line` are passed in as parameters and the
    # return value of that callable invocation is used as the exact
    # shell command to invoke the editor.
    # @example String
    #   Pry.config.editor = "emacsclient"
    # @example Callable
    #   Pry.config.editor = proc { |file, line| "emacsclient #{file} +#{line}" }
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

    # Determines whether plugins should be loaded.
    # @return [Boolean]
    attr_accessor :should_load_plugins

    # Determines whether to load files specified with the -r flag.
    # @return [Boolean]
    attr_accessor :should_load_requires

    # Determines whether to disable edit-method's auto-reloading behavior.
    # @return [Boolean]
    attr_accessor :disable_auto_reload

    # Config option for history.
    # sub-options include hist.file, hist.load, and hist.save
    # hist.file is the file to save/load history too, e.g
    # Pry.config.history.file = "~/.pry_history".
    # hist.should_load is a boolean that determines whether history will be
    # loaded from hist.file at session start.
    # hist.should_save is a boolean that determines whether history will be
    # saved to hist.file at session end.
    # @return [OpenStruct]
    attr_accessor :history

    # Config option for plugins:
    # sub-options include:
    # `plugins.enabled` (Boolean) to toggle the loading of plugins on and off wholesale. (defaults to true)
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
  end
end

