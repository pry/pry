direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

my_print = proc { |out, value| out.puts "Output is: #{value.inspect}" }
           
# Start a Pry session using the print object defined in my_print
Pry.start(TOPLEVEL_BINDING, :print => my_print)
