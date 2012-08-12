# Default commands used by Pry.
Pry::Commands = Pry::CommandSet.new

Dir[File.expand_path('../commands/*.rb', __FILE__)].each do |file|
  require file
end
