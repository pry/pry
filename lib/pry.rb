require 'pp'
require 'pry/exceptions'
require 'pry/helpers/base_helpers'
require 'pry/hooks'
require 'forwardable'

class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = Pry::Hooks.new.add_hook(:before_session, :default) do |out, target, _pry_|
    next if _pry_.quiet?
    _pry_.run_command("whereami --quiet")
  end

  # The default print
  DEFAULT_PRINT = proc do |output, value, _pry_|
    Pry::Pager.with_pager(output) do |pager|
      pager.print _pry_.config.output_prefix
      Pry::ColorPrinter.pp(value, pager, Pry::Terminal.width! - 1)
    end
  end

  # may be convenient when working with enormous objects and
  # pretty_print is too slow
  SIMPLE_PRINT = proc do |output, value|
    begin
      output.puts value.inspect
    rescue RescuableException
      output.puts "unknown"
    end
  end

  # useful when playing with truly enormous objects
  CLIPPED_PRINT = proc do |output, obj|
    output.puts Pry.inspect(obj)
  end

  # Will only show the first line of the backtrace
  DEFAULT_EXCEPTION_HANDLER = proc do |output, exception, _|
    if UserError === exception && SyntaxError === exception
      output.puts "SyntaxError: #{exception.message.sub(/.*syntax error, */m, '')}"
    else
      output.puts "#{exception.class}: #{exception.message}"
      output.puts "from #{exception.backtrace.first}"
    end
  end

  DEFAULT_PROMPT_NAME = 'pry'

  # The default prompt; includes the target and nesting level
  DEFAULT_PROMPT = [
                    proc { |target_self, nest_level, pry|
                      "[#{pry.input_array.size}] #{pry.config.prompt_name}(#{Pry.view_clip(target_self)})#{":#{nest_level}" unless nest_level.zero?}> "
                    },

                    proc { |target_self, nest_level, pry|
                      "[#{pry.input_array.size}] #{pry.config.prompt_name}(#{Pry.view_clip(target_self)})#{":#{nest_level}" unless nest_level.zero?}* "
                    }
                   ]

  DEFAULT_PROMPT_SAFE_OBJECTS = [String, Numeric, Symbol, nil, true, false]

  # A simple prompt - doesn't display target or nesting level
  SIMPLE_PROMPT = [proc { ">> " }, proc { " | " }]

  NO_PROMPT = [proc { '' }, proc { '' }]

  SHELL_PROMPT = [
                  proc { |target_self, _, _| "#{Pry.config.prompt_name} #{Pry.view_clip(target_self)}:#{Dir.pwd} $ " },
                  proc { |target_self, _, _| "#{Pry.config.prompt_name} #{Pry.view_clip(target_self)}:#{Dir.pwd} * " }
                 ]

  NAV_PROMPT = [
                proc { |pry| pry.bstack.to_s },
                proc { |pry| pry.bstack.to_s }
               ]

  # Deal with the ^D key being pressed. Different behaviour in different cases:
  #   1. In an expression behave like `!` command.
  #   2. At top-level session behave like `exit` command.
  #   3. In a nested session behave like `cd ..`.
  DEFAULT_CONTROL_D_HANDLER = proc do |eval_string, _pry_|
    if !eval_string.empty?
      eval_string.replace('') # Clear input buffer.
    elsif _pry_.bstack.one?
      _pry_.bstack.clear
      throw(:breakout)
    else
      _pry_.bstack.pop
    end
  end

  DEFAULT_SYSTEM = proc do |output, cmd, _|
    if !system(cmd)
      output.puts "Error: there was a problem executing system command: #{cmd}"
    end
  end

  # Store the current working directory. This allows show-source etc. to work if
  # your process has changed directory since boot. [Issue #675]
  INITIAL_PWD = Dir.pwd

  # This is to keep from breaking under Rails 3.2 for people who are doing that
  # IRB = Pry thing.
  module ExtendCommandBundle; end
end

require 'method_source'
require 'shellwords'
require 'stringio'
require 'coderay'
require 'slop'
require 'rbconfig'
require 'tempfile'
require 'pathname'

if Pry::Helpers::BaseHelpers.windows? && !Pry::Helpers::BaseHelpers.windows_ansi?
  begin
    require 'win32console'
    # The mswin and mingw versions of pry require win32console, so this should
    # only fail on jruby (where win32console doesn't work).
    # Instead we'll recommend ansicon, which does.
  rescue LoadError
    warn "For a better Pry experience on Windows, please use ansicon:"
    warn "   https://github.com/adoxa/ansicon"
  end
end

require 'pry/version'
require 'pry/bstack'
require 'pry/repl'
require 'pry/rbx_path'
require 'pry/code'
require 'pry/history_array'
require 'pry/helpers'
require 'pry/code_object'
require 'pry/method'
require 'pry/wrapped_module'
require 'pry/history'
require 'pry/command'
require 'pry/command_set'
require 'pry/commands'
require 'pry/plugins'
require 'pry/pry_class'
require 'pry/pry_instance'
require 'pry/cli'
require 'pry/color_printer'
require 'pry/pager'
require 'pry/terminal'
require 'pry/editor'
require 'pry/rubygem'
require "pry/indent"
require "pry/last_exception"
require "pry/prompt"
require "pry/inspector"
require 'pry/object_path'
