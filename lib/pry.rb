# (C) John Mair (banisterfiend) 2016
# MIT License
#
require 'pp'
require_relative 'pry/forwardable'
require_relative 'pry/input_lock'
require_relative 'pry/exceptions'
require_relative 'pry/helpers/base_helpers'
require_relative 'pry/hooks'

class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = Pry::Hooks.new.add_hook(:before_session, :default) do |out, target, _pry_|
    next if _pry_.quiet?
    _pry_.run_command("whereami --quiet")
  end

  # The default print
  DEFAULT_PRINT = proc do |output, value, _pry_|
    _pry_.pager.open do |pager|
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
  CLIPPED_PRINT = proc do |output, value|
    output.puts Pry.view_clip(value, id: true)
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
                  proc { |target_self, _, _pry_| "#{_pry_.config.prompt_name} #{Pry.view_clip(target_self)}:#{Dir.pwd} $ " },
                  proc { |target_self, _, _pry_| "#{_pry_.config.prompt_name} #{Pry.view_clip(target_self)}:#{Dir.pwd} * " }
                 ]

  # A prompt that includes the full object path as well as
  # input/output (_in_ and _out_) information. Good for navigation.
  NAV_PROMPT = [
                proc do |_, _, _pry_|
                  tree = _pry_.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{_pry_.input_array.count}] (#{_pry_.config.prompt_name}) #{tree}: #{_pry_.binding_stack.size - 1}> "
                end,
                proc do |_, _, _pry_|
                  tree = _pry_.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{_pry_.input_array.count}] (#{ _pry_.config.prompt_name}) #{tree}: #{_pry_.binding_stack.size - 1}* "
                end,
               ]

  # Deal with the ^D key being pressed. Different behaviour in different cases:
  #   1. In an expression behave like `!` command.
  #   2. At top-level session behave like `exit` command.
  #   3. In a nested session behave like `cd ..`.
  DEFAULT_CONTROL_D_HANDLER = proc do |eval_string, _pry_|
    if !eval_string.empty?
      eval_string.replace('') # Clear input buffer.
    elsif _pry_.binding_stack.one?
      _pry_.binding_stack.clear
      throw(:breakout)
    else
      # Otherwise, saves current binding stack as old stack and pops last
      # binding out of binding stack (the old stack still has that binding).
      _pry_.command_state["cd"] ||= Pry::Config.from_hash({}) # FIXME
      _pry_.command_state['cd'].old_stack = _pry_.binding_stack.dup
      _pry_.binding_stack.pop
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
require 'strscan'
require 'coderay'
require_relative 'pry/slop'
require 'rbconfig'
require 'tempfile'
require 'pathname'

require_relative 'pry/version'
require_relative 'pry/repl'
require_relative 'pry/rbx_path'
require_relative 'pry/code'
require_relative 'pry/history_array'
require_relative 'pry/helpers'
require_relative 'pry/code_object'
require_relative 'pry/method'
require_relative 'pry/wrapped_module'
require_relative 'pry/history'
require_relative 'pry/command'
require_relative 'pry/command_set'
require_relative 'pry/commands'
require_relative 'pry/plugins'
require_relative 'pry/core_extensions'
require_relative 'pry/pry_class'
require_relative 'pry/pry_instance'
require_relative 'pry/cli'
require_relative 'pry/color_printer'
require_relative 'pry/pager'
require_relative 'pry/terminal'
require_relative 'pry/editor'
require_relative 'pry/rubygem'
require_relative "pry/indent"
require_relative "pry/last_exception"
require_relative "pry/prompt"
require_relative "pry/inspector"
require_relative 'pry/object_path'
require_relative 'pry/output'
