# (C) John Mair (banisterfiend) 2011
# MIT License

require 'pp'
require 'set'

require 'pry/helpers/base_helpers'

class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = {
    :before_session => proc do |out, target|
      # ensure we're actually in a method
      file = target.eval('__FILE__')

      # /unknown/ for rbx
      if file !~ /(\(.*\))|<.*>/ && file !~ /__unknown__/ && file != "" && file != "-e"
        Pry.run_command "whereami 5", :output => out, :show_output => true, :context => target, :commands => Pry::Commands
      end
    end
  }

  # The default prints
  DEFAULT_PRINT = proc do |output, value|
    stringified = begin
                    value.pretty_inspect
                  rescue RescuableException => ex
                    nil
                  end

    unless String === stringified
      # Read the class name off of the singleton class to provide a default inspect.
      klass = (class << value; self; end).ancestors.first
      stringified = "#<#{klass}:0x#{value.__id__.to_s(16)}>"
      Helpers::BaseHelpers.stagger_output("output error: #{ex.inspect}", output) if ex
    end

    Helpers::BaseHelpers.stagger_output("=> #{Helpers::BaseHelpers.colorize_code(stringified)}", output)
  end

  # Will only show the first line of the backtrace
  DEFAULT_EXCEPTION_HANDLER = proc do |output, exception|
    output.puts "#{exception.class}: #{exception.message}"
    output.puts "from #{exception.backtrace.first}"
  end

  # The default prompt; includes the target and nesting level
  DEFAULT_PROMPT = [
    proc { |target_self, nest_level, _|
      if nest_level == 0
        "pry(#{Pry.view_clip(target_self)})> "
      else
        "pry(#{Pry.view_clip(target_self)}):#{Pry.view_clip(nest_level)}> "
      end
    },

    proc { |target_self, nest_level, _|
      if nest_level == 0
        "pry(#{Pry.view_clip(target_self)})* "
      else
        "pry(#{Pry.view_clip(target_self)}):#{Pry.view_clip(nest_level)}* "
      end
    }
                   ]
  # Deal with the ^D key being pressed, different behaviour in
  # different cases:
  # 1) In an expression     - behave like `!` command   (clear input buffer)
  # 2) At top-level session - behave like `exit command (break out of repl loop)
  # 3) In a nested session  - behave like `cd ..`       (pop a binding)
  DEFAULT_CONTROL_D_HANDLER = proc do |eval_string, _pry_|
    if !eval_string.empty?
      # clear input buffer
      eval_string.replace("")
    elsif _pry_.binding_stack.one?
      # ^D at top-level breaks out of loop
      _pry_.binding_stack.clear
      throw(:breakout)
    else
      # otherwise just pops a binding
      _pry_.binding_stack.pop
    end
  end

  # A simple prompt - doesn't display target or nesting level
  SIMPLE_PROMPT = [proc { ">> " }, proc { " | " }]

  SHELL_PROMPT = [
    proc { |target_self, _, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} $ " },
    proc { |target_self, _, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} * " }
  ]

  # Do not catch these exceptions
  DEFAULT_EXCEPTION_WHITELIST = Set.new([SystemExit, SignalException])

  # As a REPL, we often want to catch any unexpected exceptions that may have
  # been raised; however we don't want to go overboard and prevent the user
  # from exiting Pry when they want to.
  module Whitelistable
    def white_listed?(exception)
      case exception
      # Catch when the user hits ^C (Interrupt < SignalException), and assume
      # that they just wanted to stop the in-progress command (just like bash etc.)
      when Interrupt
        true
      # Don't catch signals (particularly not SIGTERM) as these are unlikely to be
      # intended for pry itself. We should also make sure that Kernel#exit works.
      when *@exception_whitelist
        false
      # All other exceptions will be caught.
      else
        true
      end
    end
  end

  # Sometimes we want to catch pretty much everything no matter what -- like
  # in the completions.
  class RescuableException < Exception
    extend Whitelistable
    @exception_whitelist = DEFAULT_EXCEPTION_WHITELIST
    def self.===(exception)
      white_listed? exception
    end
  end

  # Othertimes, we want the user to able to raise an arbitrary exception
  # upward
  class WhitelistRescuableException < Exception
    extend Whitelistable

    # Pass the pry instance to the RescuableException so that it can
    # know what's in your whitelist
    #   @returns [WhitelistRescuableException]
    def self.using(pry_instance)
      @pry_instance = pry_instance
      self
    end

    def self.===(exception)
      @exception_whitelist = (@pry_instance.exception_whitelist)
      white_listed? exception
    ensure
      # after we're done we do NOT want to remember the last
      # instance we worked on.
      @pry_instance = nil
    end
  end

end

require "method_source"
require 'shellwords'
require "readline"
require "stringio"
require "coderay"
require "optparse"
require "slop"
require "rubygems/dependency_installer"

if RUBY_PLATFORM =~ /mswin/ || RUBY_PLATFORM =~ /mingw/
  begin
    require 'win32console'
  rescue LoadError
    $stderr.puts "Need to `gem install win32console`"
    exit 1
  end
end

require "pry/version"
require "pry/history_array"
require "pry/helpers"
require "pry/command_set"
require "pry/commands"
require "pry/command_context"
require "pry/custom_completions"
require "pry/completion"
require "pry/plugins"
require "pry/core_extensions"
require "pry/pry_class"
require "pry/pry_instance"
