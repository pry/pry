# (C) John Mair (banisterfiend) 2011
# MIT License

direc = File.dirname(__FILE__)

$LOAD_PATH << File.expand_path(direc)

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

require "#{direc}/pry/version"
require "#{direc}/pry/hooks"
require "#{direc}/pry/print"
require "#{direc}/pry/command_base"
require "#{direc}/pry/commands"
require "#{direc}/pry/prompts"
require "#{direc}/pry/custom_completions"
require "#{direc}/pry/completion"
require "#{direc}/pry/core_extensions"
require "#{direc}/pry/pry_class"
require "#{direc}/pry/pry_instance"


# TEMPORARY HACK FOR BUG IN JRUBY 1.9 REGEX (which kills CodeRay)
if RUBY_VERSION =~ /1.9/ && RUBY_ENGINE =~ /jruby/
  Pry.color = false
end
