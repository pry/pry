require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

# Create a StringIO to contain the output data
str_output = StringIO.new

# Start a Pry session on the Fixnum 5 using str_output to store the
# output (not writing to $stdout)
Pry.start(5, :output => str_output)

# Display all the output accumulated during the session
puts str_output.string
