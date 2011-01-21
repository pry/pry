direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

# Create a StringIO that contains the input data for all the Pry objects
cmds = <<-CMDS
cd 1
status
puts 'hello from 1!!'
cd 2
nesting
puts 'hello from 2!!'
_pry_.parent.input = Readline
back
exit_all
CMDS
str_input = StringIO.new(cmds)

# Start a Pry session on the Fixnum 5 using the input data in
# str_input
Pry.input = str_input

# Start the session reading from str_input.
# Note that because `Pry.input` is set to `str_input` all nested pry
# sessions will read from `str_input` too. All pry sessions are there
# for non-interactive, except for `pry(1)` which starts off
# non-interactive but is set to be interactive by pry(2) (using
# _pry_.parent.input = Readline)

0.pry
