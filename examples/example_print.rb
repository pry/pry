require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

my_print = proc { |out, value| out.puts "Output is: #{value.inspect}" }

# Start a Pry session using the print object defined in my_print
Pry.start(TOPLEVEL_BINDING, :print => my_print)
