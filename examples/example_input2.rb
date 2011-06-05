require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

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
exit-all
CMDS

# create our StringIO object
str_input = StringIO.new(cmds)

# set global input to str_input, this means that all pry sessions
# adopt this object as their input object.
Pry.input = str_input

# Start the session reading from str_input.
# Note that because `Pry.input` is set to `str_input` all nested pry
# sessions will read from `str_input` too. All pry sessions are there
# for non-interactive, except for `pry(1)` which starts off
# non-interactive but is set to be interactive by pry(2) (using
# _pry_.parent.input = Readline)
0.pry
