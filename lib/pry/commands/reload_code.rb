class Pry
  class Command::ReloadCode < Pry::ClassCommand
    match 'reload-code'
    group 'Misc'
    description 'Reload the source file that contains the specified code object.'

    banner <<-'BANNER'
      Reload the source file that contains the specified code object.

      e.g reload-code MyClass#my_method    #=> reload a method
          reload-code MyClass              #=> reload a class
          reload-code my-command           #=> reload a pry command
          reload-code self                 #=> reload the 'current' object
          reload-code                      #=> identical to reload-code self
          reload-code -r MyClass           #=> reload class and its descendants
    BANNER

    def options(opt)
      opt.on :r, :recursive, 'Reload source file of code object and descendants', :as => String
    end

    def process
      if obj_name.empty?
        # if no parameters were provided then try to reload the
        # current file (i.e target.eval("__FILE__"))
        reload_current_file
      else
        code_object = Pry::CodeObject.lookup(obj_name, _pry_)
        opts.present?(:recursive) ? recursive_reload(obj_name) : reload_code_object(code_object)
      end
    end

    private

    def lookup_history
      @lookup_history ||= {}
    end

    def add_to_lookup_history(value)
      @lookup_history[value] = true
    end

    def recursive_reload(lookup_class)
      nested_code_object(lookup_class).each {|co| reload_code_object(co)}
    end

    def nested_code_object(lookup_class,parent=nil)
      args = Array(lookup_class)
      head,tail = args.shift,args
      lookup_class = build_lookup_class(head,parent)

      return [] if head.nil? || head.empty? || lookup_history[head]
      add_to_lookup_history(head)

      resultant_code_obj = Pry::CodeObject.lookup(lookup_class,_pry_)
      constants = resultant_code_obj.constants.map(&:to_s)

      Array(resultant_code_obj) + nested_code_object(constants,lookup_class) + nested_code_object(tail,lookup_class)
    end

    def build_lookup_class(lc,parent)
      parent.nil? ? lc : "#{parent}::#{lc}"
    end

    def current_file
      File.expand_path target.eval("__FILE__")
    end

    def reload_current_file
      if !File.exists?(current_file)
        raise CommandError, "Current file: #{current_file} cannot be found on disk!"
      end

      load current_file
      output.puts "The current file: #{current_file} was reloaded!"
    end

    def reload_code_object(code_object)
      check_for_reloadability(code_object)
      load code_object.source_file
      output.puts "#{code_object.wrapped} was reloaded!"
    end

    def obj_name
      @obj_name ||= args.join(" ")
    end

    def check_for_reloadability(code_object)
      if !code_object || !code_object.source_file
        raise CommandError, "Cannot locate #{obj_name}!"
      elsif !File.exists?(code_object.source_file)
        raise CommandError, "Cannot reload #{obj_name} as it has no associated file on disk. File found was: #{code_object.source_file}"
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::ReloadCode)
  Pry::Commands.alias_command 'reload-method', 'reload-code'
end
