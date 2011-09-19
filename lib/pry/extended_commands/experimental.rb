class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do

      command "reload-method", "Reload the source specifically for a method", :requires_gem => "method_reload" do |meth_name|
        if (method = Pry::Method.from_str(meth_name, target)).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        method.reload
      end
    end
  end
end
