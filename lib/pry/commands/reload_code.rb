class Pry
  class Command::ReloadCode < Pry::ClassCommand
    match 'reload-code'
    group 'Misc'
    description 'Reload the source file that contains the specified code object.'

    banner <<-'BANNER'
      Reload the source file that contains the specified code object.
    BANNER

    def process
      code_object = Pry::CodeObject.lookup(obj_name, _pry_)

      check_for_reloadability(code_object)
      reload_code_object(code_object)
    end

    private

    def reload_code_object(code_object)
      load code_object.source_file
      output.puts "#{obj_name} was reloaded!"
    end

    def obj_name
      @obj_name ||= args.empty? ? "self" : args.join(" ")
    end

    def check_for_reloadability(code_object)
      if !code_object
        raise CommandError, "Cannot locate #{obj_name}!"
      elsif !File.exists?(code_object.source_file)
        raise CommandError, "Cannot reload #{obj_name} as it has no associated file on disk. File found was: #{code_object.source_file}"
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::ReloadCode)
end
