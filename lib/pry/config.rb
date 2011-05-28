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

    # Get/Set the Hash that defines Pry hooks used by default by all Pry
    # instances.
    # @return [Hash] The hooks used by default by all Pry instances.
    # @example
    #   Pry.hooks :before_session => proc { puts "hello" },
    #     :after_session => proc { puts "goodbye" }
    attr_accessor :hooks

    # Get the array of Procs to be used for the prompts by default by
    # all Pry instances.
    # @return [Array<Proc>] The array of Procs to be used for the
    #   prompts by default by all Pry instances.
    attr_accessor :prompt

    # Get/Set the Proc that defines extra Readline completions (on top
    # of the ones defined for IRB).
    # @return [Proc] The Proc that defines extra Readline completions (on top
    # @example Add file names to completion list
    #   Pry.custom_completions = proc { Dir.entries('.') }
    attr_accessor :custom_completions

    # The default editor to use. Defaults to $EDITOR or nano if
    # $EDITOR is not defined.
    # If `editor` is a String then that string is used as the shell
    # command to invoke the editor. If `editor` is callable (e.g a
    # Proc) then `file` and `line` are passed in as parameters and the
    # return value of that callable invocation is used as the exact
    # shell command to invoke the editor.
    # @example String
    #   Pry.editor = "emacsclient"
    # @example Callable
    #   Pry.editor = proc { |file, line| "emacsclient #{file} +#{line}" }
    # @return [String, #call]
    attr_accessor :editor

    # @return [Boolean] Toggle Pry color on and off.
    attr_accessor :color

    # @return [Boolean] Toggle paging on and off.
    attr_accessor :pager

    # Determines whether the rc file (~/.pryrc) should be loaded.
    # @return [Boolean]
    attr_accessor :should_load_rc
  end
end

