direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

my_hooks = {
  :before_session => proc { |out, obj| out.puts "Opening #{obj}." },
  :after_session => proc { |out, obj| out.puts "Closing #{obj}." }
}
           
# Start a Pry session using the hooks hash defined in my_hooks
Pry.start(TOPLEVEL_BINDING, :hooks => my_hooks)
