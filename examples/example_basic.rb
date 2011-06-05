require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

# define a local.
a = "a local variable"

# defing a top-level method.
def hello
  puts "hello world!"
end

# Start pry session at top-level.
# The local variable `a` and the `hello` method will
# be accessible.
puts __LINE__
binding.pry
