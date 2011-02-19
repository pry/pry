# (C) John Mair (banisterfiend) 2011
# MIT License

direc = File.dirname(__FILE__)

require "method_source"
require "readline"

Dir["#{direc}/pry/*.rb"].each do |file|
  require file
end
