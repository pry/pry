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
      def lookup(str, _pry_, options={})
        co = new(str, _pry_, options)

        co.default_lookup || co.method_or_class_lookup ||
          co.command_lookup || co.empty_lookup
      end
    end

    attr_accessor :str
    attr_accessor :target
    attr_accessor :pry
    attr_accessor :super_level

    def initialize(str, _pry_, options={})
      options = {
        :super => 0,
      }.merge!(options)

      @str = str
      @pry = _pry_
      @target = _pry_.current_context
      @super_level = options[:super]
    end

    def command_lookup
      # TODO: just make it so find_command_by_match_or_listing doesn't
      # raise?
      pry.commands.find_command_by_match_or_listing(str) rescue nil
    end

    def empty_lookup
      return nil if str && !str.empty?

      if internal_binding?(target)
        mod = target_self.is_a?(Module) ? target_self : target_self.class
        Pry::WrappedModule(mod)
      else
        Pry::Method.from_binding(target)
      end
    end

    # lookup variables and constants and `self` that are not modules
    def default_lookup

      # we skip instance methods as we want those to fall through to method_or_class_lookup()
      if safe_to_evaluate?(str) && !looks_like_an_instance_method?(str)
        obj = target.eval(str)

        # restrict to only objects we KNOW for sure support the full API
        # Do NOT support just any object that responds to source_location
        if sourcable_object?(obj)
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
      return nil if str.to_s.empty?

      obj = if str =~ /::(?:\S+)\Z/
        Pry::WrappedModule.from_str(str,target) || Pry::Method.from_str(str, target)
      else
        Pry::Method.from_str(str,target) || Pry::WrappedModule.from_str(str, target)
      end

      lookup_super(obj, super_level)
    end

    private

    def sourcable_object?(obj)
      [::Proc, ::Method, ::UnboundMethod].any? { |o| obj.is_a?(o) }
    end


    # Returns true if `str` looks like a method, i.e Klass#method
    # We need to consider this case because method lookups should fall
    # through to the `method_or_class_lookup()` method but a
    # defined?() on a "Klass#method` string will see the `#` as a
    # comment and only evaluate the `Klass` part.
    # @param [String] str
    # @return [Boolean] Whether the string looks like an instance method.
    def looks_like_an_instance_method?(str)
      str =~ /\S#\S/
    end

    # We use this method to decide whether code is safe to eval. Method's are
    # generally not, but everything else is.
    # TODO: is just checking != "method" enough??
    # TODO: see duplication of this method in Pry::WrappedModule
    # @param [String] str The string to lookup
    # @return [Boolean]
    def safe_to_evaluate?(str)
      return true if str.strip == "self"
      kind = target.eval("defined?(#{str})")
      kind =~ /variable|constant/
    end

    def target_self
      target.eval('self')
    end

    # grab the nth (`super_level`) super of `obj
    # @param [Object] obj
    # @param [Fixnum] super_level How far up the super chain to ascend.
    def lookup_super(obj, super_level)
      return nil if !obj

      sup = obj.super(super_level)
      if !sup
        raise Pry::CommandError, "No superclass found for #{obj.wrapped}"
      else
        sup
      end
    end
  end
end
