# (C) John Mair (banisterfiend) 2011
# MIT License

require 'pp'
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
    begin
      Helpers::BaseHelpers.stagger_output("=> #{Helpers::BaseHelpers.colorize_code(value.pretty_inspect)}", output)
    rescue NoMethodError
      output.puts "=> unknown"
    end
  end

  # Will only show the first line of the backtrace
  DEFAULT_EXCEPTION_HANDLER = proc do |output, exception|
    output.puts "#{exception.class}: #{exception.message}"
    output.puts "from #{exception.backtrace.first}"
  end

  # The default prompt; includes the target and nesting level
  DEFAULT_PROMPT = [
    proc { |target_self, nest_level|
      if nest_level == 0
        "pry(#{Pry.view_clip(target_self)})> "
      else
        "pry(#{Pry.view_clip(target_self)}):#{Pry.view_clip(nest_level)}> "
      end
    },

    proc { |target_self, nest_level|
      if nest_level == 0
        "pry(#{Pry.view_clip(target_self)})* "
      else
        "pry(#{Pry.view_clip(target_self)}):#{Pry.view_clip(nest_level)}* "
      end
    }
  ]

  # A simple prompt - doesn't display target or nesting level
  SIMPLE_PROMPT = [proc { ">> " }, proc { " | " }]

  SHELL_PROMPT = [
    proc { |target_self, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} $ " },
    proc { |target_self, _| "pry #{Pry.view_clip(target_self)}:#{Dir.pwd} * " }
  ]

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
      when SystemExit, SignalException
        false
      # All other exceptions will be caught.
      else
        true
      end
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
