class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do

      command "reload-method", "Reload the source specifically for a method", :requires_gem => "method_reload" do |meth_name|
        meth = get_method_or_print_error(meth_name, target, {}, :no_cmd)
        meth.reload if meth
      end
    end
  end
end
