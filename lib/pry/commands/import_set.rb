class Pry
  Pry::Commands.create_command "import-set" do
    group "Commands"
    description "Import a command set."

    def process(command_set_name)
      raise CommandError, "Provide a command set name" if command_set.nil?

      set = target.eval(arg_string)
      _pry_.commands.import set
    end
  end
end
