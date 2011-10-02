class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do

      command "reload-method", "Reload the source specifically for a method", :requires_gem => "method_reload" do |meth_name|
        meth = get_method_or_raise(meth_name, target, {}, :omit_help)
        meth.reload
      end
    end
  end
end
