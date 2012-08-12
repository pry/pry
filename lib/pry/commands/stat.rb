class Pry
  Pry::Commands.create_command "stat" do
    group 'Introspection'
    description "View method information and set _file_ and _dir_ locals."
    command_options :shellwords => false

    banner <<-BANNER
        Usage: stat [OPTIONS] [METH]
        Show method information for method METH and set _file_ and _dir_ locals.
        e.g: stat hello_method
    BANNER

    def options(opt)
      method_options(opt)
    end

    def process
      meth = method_object
      output.puts unindent <<-EOS
        Method Information:
        --
        Name: #{meth.name}
        Owner: #{meth.owner ? meth.owner : "Unknown"}
        Visibility: #{meth.visibility}
        Type: #{meth.is_a?(::Method) ? "Bound" : "Unbound"}
        Arity: #{meth.arity}
        Method Signature: #{meth.signature}
        Source Location: #{meth.source_location ? meth.source_location.join(":") : "Not found."}
      EOS
    end
  end
end
