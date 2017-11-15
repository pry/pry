# Default commands used by Pry.
Pry::Commands = Pry::CommandSet.new

# Use `Kernel.require` to avoid the rubygems monkey patch.
# Also use an absolute path to avoid scanning $LOAD_PATH.
glob = File.expand_path File.join(__FILE__, "../commands/*.rb")
Dir[glob].each{|f| Kernel.require(f) }
