# (C) John Mair (banisterfiend) 2011
# MIT License
#

require 'pp'
require 'pry/helpers/base_helpers'
require 'pry/hooks'

class Pry
  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = Pry::Hooks.new.add_hook(:before_session, :default) do |out, target, _pry_|
    next if _pry_.quiet?
    _pry_.run_command("whereami --quiet", "", target)
  end

  # The default print
  DEFAULT_PRINT = proc do |output, value|
    output_with_default_format(output, value, :hashrocket => true)
  end

  def self.output_with_default_format(output, value, options = {})
    stringified = begin
                    value.pretty_inspect
                  rescue RescuableException
                    nil
                  end

    unless String === stringified
      # Read the class name off of the singleton class to provide a default
      # inspect.
      klass = (class << value; self; end).ancestors.first
      stringified = "#<#{klass}:0x#{value.__id__.to_s(16)}>"
    end

    nonce = rand(0x100000000).to_s(16) # whatever

    stringified.gsub!(/#</, "%<#{nonce}")
    # Don't recolorize output with color (for cucumber, looksee, etc.) [Issue #751]
    colorized = if stringified =~ /\e\[/
                  stringified
                else
                  Helpers::BaseHelpers.colorize_code(stringified)
                end

    # avoid colour-leak from CodeRay and any of the users' previous output
    colorized = colorized.sub(/(\n*)\z/, "\e[0m\\1") if Pry.color

    result = colorized.gsub(/%<(.*?)#{nonce}/, '#<\1')
    result = "=> #{result}"if options[:hashrocket]
    Helpers::BaseHelpers.stagger_output(result, output)
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

  # A simple prompt - doesn't display target or nesting level
  SIMPLE_PROMPT = [proc { ">> " }, proc { " | " }]

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
      # Store the entire binding stack before popping. Useful for `cd -`.
      if _pry_.command_state['cd'].nil?
        _pry_.command_state['cd'] = OpenStruct.new
      end
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

  # An Exception Tag (cf. Exceptional Ruby) that instructs Pry to show the error in
  # a more user-friendly manner. This should be used when the exception happens within
  # Pry itself as a direct consequence of the user typing something wrong.
  #
  # This allows us to distinguish between the user typing:
  #
  # pry(main)> def )
  # SyntaxError: unexpected )
  #
  # pry(main)> method_that_evals("def )")
  # SyntaxError: (eval):1: syntax error, unexpected ')'
  # from ./a.rb:2 in `eval'
  module UserError; end

  # Catches SecurityErrors if $SAFE is set
  module TooSafeException
    def self.===(exception)
      $SAFE > 0 && SecurityError === exception
    end
  end

  # Don't catch these exceptions
  DEFAULT_EXCEPTION_WHITELIST = [SystemExit, SignalException, Pry::TooSafeException]

  # CommandErrors are caught by the REPL loop and displayed to the user. They
  # indicate an exceptional condition that's fatal to the current command.
  class CommandError < StandardError; end
  class MethodNotFound < CommandError; end

  # indicates obsolete API
  class ObsoleteError < StandardError; end

  # This is to keep from breaking under Rails 3.2 for people who are doing that
  # IRB = Pry thing.
  module ExtendCommandBundle
  end
end

if Pry::Helpers::BaseHelpers.mri_18?
  begin
  require 'ruby18_source_location'
  rescue LoadError
  end
end

require 'method_source'
require 'shellwords'
require 'stringio'
require 'coderay'
require 'slop'
require 'rbconfig'
require 'tempfile'

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
    warn "For a better pry experience, please use ansicon: http://adoxa.3eeweb.com/ansicon/"
  end
end

begin
  require 'bond'
rescue LoadError
end

require 'pry/version'
require 'pry/rbx_method'
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
require 'pry/pager'
require 'pry/terminal'
require 'pry/editor'
require 'pry/rubygem'
