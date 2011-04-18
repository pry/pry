class Pry

  # The default hooks - display messages when beginning and ending Pry sessions.
  DEFAULT_HOOKS = {

    :before_session => proc do |out, target|
      # ensure we're actually in a method
      meth_name = target.eval('__method__')
      file = target.eval('__FILE__')

      # /unknown/ for rbx
      if file !~ /(\(.*\))|<.*>/ && file !~ /__unknown__/ && file != "" && file != "-e"
        Pry.run_command "whereami 5", :output => out, :show_output => true, :context => target, :commands => Pry::Commands
      end
    end,
  }
end
