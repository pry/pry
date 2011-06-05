require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

my_hooks = {
  :before_session => proc { |out, target| out.puts "Opening #{target.eval('self')}." },
  :after_session => proc { |out, target| out.puts "Closing #{target.eval('self')}." }
}

# Start a Pry session using the hooks hash defined in my_hooks
Pry.start(TOPLEVEL_BINDING, :hooks => my_hooks)
