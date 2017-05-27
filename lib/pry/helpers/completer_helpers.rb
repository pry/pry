class Pry
  module Helpers
    module CompleterHelpers
      module_function

      # For MRI we simply use RubyVM.stat, for other rubies we count
      # all defined instance methods. While we still iterate over ObjectSpace
      # we can have improvements from not sorting methods list.
      def methods_cache_version
        return RubyVM.stat if defined?(RubyVM.stat)
        ObjectSpace.each_object(Module).inject(0) do |s, m|
          s + (m.respond_to?(:instance_methods) ? m.instance_methods(false).count : 0)
        end
      end

      def all_available_methods
        result = []
        to_ignore = ignored_modules
        ObjectSpace.each_object(Module) do |m|
          # some gems overrides .hash method for their modules,
          # so we rescue invalid invocations and ignore them
          next if (to_ignore.include?(m) rescue true)

          # jruby doesn't always provide #instance_methods() on each
          # object.
          if m.respond_to?(:instance_methods)
            result.concat m.instance_methods(false).collect(&:to_s)
          end
        end
        result.uniq!
        result.sort!
        result
      end

      def ignored_modules
        # We could cache the result, but IRB is not loaded by default.
        # And this is very fast anyway.
        # By using this approach, we avoid Module#name calls, which are
        # relatively slow when there are a lot of anonymous modules defined.
        s = Set.new

        scanner = lambda do |m|
          next if s.include?(m) # IRB::ExtendCommandBundle::EXCB recurses.
          s << m
          m.constants(false).each do |c|
            value = m.const_get(c)
            scanner.call(value) if value.is_a?(Module)
          end
        end

        # FIXME: Add Pry here as well?
        %w(IRB SLex RubyLex RubyToken).each do |module_name|
          sym = module_name.to_sym
          next unless Object.const_defined?(sym)
          scanner.call(Object.const_get(sym))
        end

        s.delete(IRB::Context) if defined?(IRB::Context)

        s
      end
    end
  end
end
