# (C) John Mair (banisterfiend) 2013
# MIT License
#
require 'pp'

require 'pry/input_lock'
require 'pry/exceptions'
require 'pry/helpers/base_helpers'
require 'pry/hooks'

require 'securerandom'
require 'forwardable'

class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = Pry::Hooks.new.add_hook(:before_session, :default) do |out, target, _pry_|
    next if _pry_.quiet?
    _pry_.run_command("whereami --quiet")
  end

  # The default print
  DEFAULT_PRINT = proc do |output, value|
    Pry::Pager.with_pager(output) do |pager|
      pager.print "=> "
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
    output.puts Pry.view_clip(value)
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
                      "[#{pry.input_array.size}] #{Pry.config.prompt_name}(#{Pry.view_clip(target_self)})#{":#{nest_level}" unless nest_level.zero?}> "
                    },

                    proc { |target_self, nest_level, pry|
                      "[#{pry.input_array.size}] #{Pry.config.prompt_name}(#{Pry.view_clip(target_self)})#{":#{nest_level}" unless nest_level.zero?}* "
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

  # A prompt that includes the full object path as well as
  # input/output (_in_ and _out_) information. Good for navigation.
  NAV_PROMPT = [
                proc do |conf|
                  tree = conf.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{conf.expr_number}] (#{Pry.config.prompt_name}) #{tree}: #{conf.nesting_level}> "
                end,
                proc do |conf|
                  tree = conf.binding_stack.map { |b| Pry.view_clip(b.eval("self")) }.join " / "
                  "[#{conf.expr_number}] (#{ Pry.config.prompt_name}) #{tree}: #{conf.nesting_level}* "
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
      _pry_.command_state["cd"] ||= OpenStruct.new # FIXME
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
require 'coderay'
require 'slop'
require 'rbconfig'
require 'tempfile'
require 'pathname'

begin
  require 'readline'
rescue LoadError
  warn "You're running a version of ruby with no Readline support"
  warn "Please `gem install rb-readline` or recompile ruby --with-readline."
  exit!
end

if Pry::Helpers::BaseHelpers.jruby?
  begin
    require 'ffi'
  rescue LoadError
    warn "Need to `gem install ffi`"
  end
end

if Pry::Helpers::BaseHelpers.windows? && !Pry::Helpers::BaseHelpers.windows_ansi?
  begin
    require 'win32console'
    # The mswin and mingw versions of pry require win32console, so this should
    # only fail on jruby (where win32console doesn't work).
    # Instead we'll recommend ansicon, which does.
  rescue LoadError
    warn "For a better pry experience, please use ansicon: https://github.com/adoxa/ansicon"
  end
end

begin
  require 'bond'
rescue LoadError
end

require 'pry/version'
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
require 'pry/custom_completions'
require 'pry/completion'
require 'pry/plugins'
require 'pry/core_extensions'
require 'pry/pry_class'
require 'pry/pry_instance'
require 'pry/cli'
require 'pry/color_printer'
require 'pry/pager'
require 'pry/terminal'
require 'pry/editor'
require 'pry/rubygem'
