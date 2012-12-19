class Pry
  class CodeObject

    class << self
      def lookup(str, target, _pry_, options={})
        co = new(str, target, _pry_, options)
        co.other_object || co.method_or_class || co.command
      end
    end

    attr_accessor :str
    attr_accessor :target
    attr_accessor :pry
    attr_accessor :super_level

    def initialize(str, target, _pry_, options={})
      options = {
        :super => 0
      }.merge!(options)

      @str = str
      @target = target
      @pry = _pry_
      @super_level = options[:super]
    end

    def command
      pry.commands[str]
    end

    def other_object
      if target.eval("defined? #{str} ") =~ /variable|constant/
        obj = target.eval(str)

        if obj.respond_to?(:source_location)
          Pry::Method(obj)
        elsif !obj.is_a?(Module)
          Pry::WrappedModule(obj.class)
        else
          nil
        end
      end

    rescue Pry::RescuableException
      nil
    end

    def method_or_class
      obj = if str =~ /::(?:\S+)\Z/
        Pry::WrappedModule.from_str(str,target) || Pry::Method.from_str(str, target)
      else
        Pry::Method.from_str(str,target) || Pry::WrappedModule.from_str(str, target)
      end

      sup = obj.super(super_level) if obj
      if obj && !sup
        raise ArgumentError, "No superclass found for #{obj.wrapped}"
      else
        sup
      end
    end
  end
end
