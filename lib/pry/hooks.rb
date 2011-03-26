class Pry

  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = {
    
    :before_session => proc do |out, target|
      out.puts "Beginning Pry session for #{Pry.view_clip(target.eval('self'))}"

      # ensure we're actually in a method
      meth_name = target.eval('__method__')
      file = target.eval('__FILE__')

      # /unknown/ for rbx
      if file !~ /(\(.*\))|<.*>/ && file !~ /__unknown__/
        Pry.run_command "whereami", :output => out, :show_output => true, :context => target, :commands => Pry::Commands
      end
    end,
    
    :after_session => proc { |out, target| out.puts "Ending Pry session for #{Pry.view_clip(target.eval('self'))}" }
  }
end
