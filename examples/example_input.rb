direc = File.dirname(__FILE__)

require 'rubygems'
require "#{direc}/../lib/pry"

# Create a StringIO that contains the input data
str_input = StringIO.new("puts 'hello world!'\nputs \"I am in \#{self}\"\nexit")

# Start a Pry session on the Fixnum 5 using the input data in str_input
Pry.start(5, :input => str_input)
