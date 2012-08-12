class Pry
  Pry::Commands.create_command "reload-method" do
    group 'Misc'
    description "Reload the source file that contains the specified method"

    def process(meth_name)
      meth = get_method_or_raise(meth_name, target, {}, :omit_help)

      if meth.source_type == :c
        raise CommandError, "Can't reload a C method."
      elsif meth.dynamically_defined?
        raise CommandError, "Can't reload an eval method."
      else
        file_name = meth.source_file
        load file_name
        output.puts "Reloaded #{file_name}."
      end
    end
  end
end
