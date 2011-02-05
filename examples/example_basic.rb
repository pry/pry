direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

# define a local.
a = "a local variable"

# defing a top-level method.
def hello
  puts "hello world!"
end

# Start pry session at top-level.
# The local variable `a` and the `hello` method will
# be accessible.
pry
