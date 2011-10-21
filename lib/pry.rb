# (C) John Mair (banisterfiend) 2011
# MIT License
#

require 'pp'
require 'pry/helpers/base_helpers'
class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = {
    :before_session => proc do |out, target, _pry_|
      # ensure we're actually in a method
      file = target.eval('__FILE__')

      # /unknown/ for rbx
      if file == Pry.eval_path  || (file !~ /(\(.*\))|<.*>/ && file !~ /__unknown__/ && file != "" && file != "-e")
        _pry_.process_line("whereami 5", "", target)
      end
    end
  }

  # The default print
  DEFAULT_PRINT = proc do |output, value|
    stringified = begin
                    value.pretty_inspect
                  rescue RescuableException
                    nil
                  end

    unless String === stringified
      # Read the class name off of the singleton class to provide a default inspect.
      klass = (class << value; self; end).ancestors.first
      stringified = "#<#{klass}:0x#{value.__id__.to_s(16)}>"
    end

    nonce = rand(0x100000000).to_s(16) # whatever

    colorized = Helpers::BaseHelpers.colorize_code(stringified.gsub(/#</, "%<#{nonce}"))

    Helpers::BaseHelpers.stagger_output("=> #{colorized.gsub(/%<(.*?)#{nonce}/, '#<\1')}", output)
  end

  # may be convenient when working with enormous objects and
  # pretty_print is too slow
  SIMPLE_PRINT = proc do |output, value|
    begin
      output.puts "=> #{value.inspect}"
    rescue RescuableException
      output.puts "=> unknown"
    end
  end

  # useful when playing with truly enormous objects
  CLIPPED_PRINT = proc do |output, value|
    output.puts "=> #{Pry.view_clip(value)}"
  end

  # Will only show the first line of the backtrace
  DEFAULT_EXCEPTION_HANDLER = proc do |output, exception, _|
    output.puts "#{exception.class}: #{exception.message}"
    output.puts "from #{exception.backtrace.first}"
  end

  # Don't catch these exceptions
  DEFAULT_EXCEPTION_WHITELIST = [SystemExit, SignalException]

  # The default prompt; includes the target and nesting level
  DEFAULT_PROMPT = [
                    proc { |target_self, nest_level, pry|
                      if nest_level == 0
                        "[#{pry.input_array.size}] pry(#{Pry.view_clip(target_self)})> "
                      else
                        "[#{pry.input_array.size}] pry(#{Pry.view_clip(target_self)}):#{nest_level}> "
                      end
                    },

                    proc { |target_self, nest_level, pry|
                      if nest_level == 0
                        "[#{pry.input_array.size}] pry(#{Pry.view_clip(target_self)})* "
                      else
                        "[#{pry.input_array.size}] pry(#{Pry.view_clip(target_self)}):#{nest_level}* "
                      end
                    }
                   ]

  # A simple prompt - doesn't display target or nesting level
  SIMPLE_PROMPT = [proc { ">> " }, proc { " | " }]

  SHELL_PROMPT = [
                  proc { |target_self, _, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} $ " },
                  proc { |target_self, _, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} * " }
                 ]

  # A prompt that includes the full object path as well as
  # input/output (_in_ and _out_) information. Good for navigation.
  NAV_PROMPT = [
                proc do |_, level, pry|
                  tree = pry.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{pry.input_array.size}] (pry) #{tree}: #{level}> "
                end,
                proc do |_, level, pry|
                  tree = pry.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{pry.input_array.size}] (pry) #{tree}: #{level}* "
                end,
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

  DEFAULT_SYSTEM = proc do |output, cmd, _|
    if !system(cmd)
      output.puts "Error: there was a problem executing system command: #{cmd}"
    end
  end

  # As a REPL, we often want to catch any unexpected exceptions that may have
  # been raised; however we don't want to go overboard and prevent the user
  # from exiting Pry when they want to.
  module RescuableException
    def self.===(exception)
      case exception
        # Catch when the user hits ^C (Interrupt < SignalException), and assume
        # that they just wanted to stop the in-progress command (just like bash etc.)
      when Interrupt
        true
        # Don't catch signals (particularly not SIGTERM) as these are unlikely to be
        # intended for pry itself. We should also make sure that Kernel#exit works.
      when *Pry.config.exception_whitelist
        false
        # All other exceptions will be caught.
      else
        true
      end
    end
  end

  # CommandErrors are caught by the REPL loop and displayed to the user. They
  # indicate an exceptional condition that's fatal to the current command.
  class CommandError < StandardError
  end
end

require "method_source"
require 'shellwords'
require "readline"
require "stringio"
require "coderay"
require "optparse"
require "slop"

if RUBY_PLATFORM =~ /jruby/
  begin
    require 'ffi'
  rescue LoadError
    $stderr.puts "Need to `gem install ffi`"
  end
end

if RUBY_PLATFORM =~ /mswin/ || RUBY_PLATFORM =~ /mingw/
  begin
    require 'win32console'
  rescue LoadError
    $stderr.puts "Need to `gem install win32console`"
    exit 1
  end
end

require "pry/version"
require "pry/rbx_method"
require "pry/rbx_path"
require "pry/method"
require "pry/history_array"
require "pry/helpers"
require "pry/history"
require "pry/command_set"
require "pry/commands"
require "pry/command_context"
require "pry/custom_completions"
require "pry/completion"
require "pry/plugins"
require "pry/core_extensions"
require "pry/pry_class"
require "pry/pry_instance"
