class Pry
  class CodeObject
    module Helpers
      # we need this helper as some Pry::Method objects can wrap Procs
      # @return [Boolean]
      def real_method_object?
        is_a?(::Method) || is_a?(::UnboundMethod)
      end

      def c_method?
        real_method_object? && source_type == :c
      end

      def module_with_yard_docs?
        is_a?(WrappedModule) && yard_docs?
      end

      def command?
        is_a?(Module) && self <= Pry::Command
      end
    end

    include Pry::Helpers::CommandHelpers

    class << self
      def lookup(str, target, _pry_, options={})
        co = new(str, target, _pry_, options)

        co.default_lookup || co.method_or_class_lookup ||
          co.command_lookup || co.binding_lookup
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

    def command_lookup
      # TODO: just make it so find_command_by_match_or_listing doesn't
      # raise?
      pry.commands.find_command_by_match_or_listing(str) rescue nil
    end

    # extract the object from the binding
    def binding_lookup
      return nil if str && !str.empty?

      if internal_binding?(target)
        mod = target_self.is_a?(Module) ? target_self : target_self.class
        Pry::WrappedModule(mod)
      else
        Pry::Method.from_binding(target)
      end
    end

    # lookup variables and constants that are not modules
    def default_lookup
      if str !~ /\S#\S/ && target.eval("defined? #{str} ") =~ /variable|constant/
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

    def method_or_class_lookup
      # we need this here because stupid Pry::Method.from_str() does a
      # Pry::Method.from_binding when str is nil.
      # Once we refactor Pry::Method.from_str() so it doesnt lookup
      # from bindings, we can get rid of this check
      return nil if !str || str.empty?

      obj = if str =~ /::(?:\S+)\Z/
        Pry::WrappedModule.from_str(str,target) || Pry::Method.from_str(str, target)
      else
        Pry::Method.from_str(str,target) || Pry::WrappedModule.from_str(str, target)
      end

      sup = obj.super(super_level) if obj
      if obj && !sup
        raise Pry::CommandError, "No superclass found for #{obj.wrapped}"
      else
        sup
      end
    end

    private
    def target_self
      target.eval('self')
    end
  end
end
