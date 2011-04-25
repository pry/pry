# (C) John Mair (banisterfiend) 2011
# MIT License

require "method_source"
require 'shellwords'
require "readline"
require "stringio"
require "coderay"

if RUBY_PLATFORM =~ /mswin/ || RUBY_PLATFORM =~ /mingw/
  begin
    require 'win32console'
  rescue LoadError
    $stderr.puts "Need to `gem install win32console`"
    exit 1
  end
end

require "pry/version"
require "pry/hooks"
require "pry/print"
require "pry/command_set"
require "pry/command_base" # to be romved
require "pry/commands"
require "pry/command_context"
require "pry/prompts"
require "pry/custom_completions"
require "pry/completion"
require "pry/core_extensions"
require "pry/pry_class"
require "pry/pry_instance"


# TEMPORARY HACK FOR BUG IN JRUBY 1.9 REGEX (which kills CodeRay)
if RUBY_VERSION =~ /1.9/ && RUBY_ENGINE =~ /jruby/
  Pry.color = false
end
