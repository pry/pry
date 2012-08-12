# Default commands used by Pry.
Pry::Commands = Pry::CommandSet.new

Dir[File.expand_path('../default_commands/*.rb', __FILE__)].each do |file|
  require file
end

Dir[File.expand_path('../extended_commands/*.rb', __FILE__)].each do |file|
  require file
end
