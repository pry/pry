class Pry
  class Command::Edit
    class MethodPatcher
      attr_accessor :method_object
      attr_accessor :target
      attr_accessor :_pry_

      def initialize(method_object, target, _pry_)
        @method_object = method_object
        @target        = target
        @_pry_         = _pry_
      end

      # perform the patch
      def perform_patch
        lines = method_object.source.lines.to_a
        lines[0] = definition_line_for_owner(lines[0])
        source = wrap_for_nesting(wrap_for_owner(Pry::Editor.edit_tempfile_with_content(lines)))

        if method_object.alias?
          with_method_transaction do
            _pry_.evaluate_ruby source
            Pry.binding_for(method_object.owner).eval("alias #{method_object.name} #{original_name}")
          end
        else
          _pry_.evaluate_ruby source
        end
      end

      private

      # Run some code ensuring that at the end target#meth_name will not have changed.
      #
      # When we're redefining aliased methods we will overwrite the method at the
      # unaliased name (so that super continues to work). By wrapping that code in a
      # transation we make that not happen, which means that alias_method_chains, etc.
      # continue to work.
      #
      # @param [String] meth_name  The method name before aliasing
      # @param [Module] target  The owner of the method
      def with_method_transaction
        target = Pry.binding_for(target)
        temp_name = "__pry_#{method_object.original_name}__"

        target.eval("alias #{temp_name} #{method_object.original_name}")
        yield
        target.eval("alias #{method_object.original_name} #{temp_name}")
      ensure
        target.eval("undef #{temp_name}") rescue nil
      end

      # Update the definition line so that it can be eval'd directly on the Method's
      # owner instead of from the original context.
      #
      # In particular this takes `def self.foo` and turns it into `def foo` so that we
      # don't end up creating the method on the singleton class of the singleton class
      # by accident.
      #
      # This is necessarily done by String manipulation because we can't find out what
      # syntax is needed for the argument list by ruby-level introspection.
      #
      # @param String   The original definition line. e.g. def self.foo(bar, baz=1)
      # @return String  The new definition line. e.g. def foo(bar, baz=1)
      def definition_line_for_owner(line)
        if line =~ /^def (?:.*?\.)?#{Regexp.escape(method_object.original_name)}(?=[\(\s;]|$)/
          "def #{method_object.original_name}#{$'}"
        else
          raise CommandError, "Could not find original `def #{method_object.original_name}` line to patch."
        end
      end

      # Update the source code so that when it has the right owner when eval'd.
      #
      # This (combined with definition_line_for_owner) is backup for the case that
      # wrap_for_nesting fails, to ensure that the method will stil be defined in
      # the correct place.
      #
      # @param [String] source  The source to wrap
      # @return [String]
      def wrap_for_owner(source)
        Thread.current[:__pry_owner__] = method_object.owner
        source = "Thread.current[:__pry_owner__].class_eval do\n#{source}\nend"
      end

      # Update the new source code to have the correct Module.nesting.
      #
      # This method uses syntactic analysis of the original source file to determine
      # the new nesting, so that we can tell the difference between:
      #
      #   class A; def self.b; end; end
      #   class << A; def b; end; end
      #
      # The resulting code should be evaluated in the TOPLEVEL_BINDING.
      #
      # @param [String] source  The source to wrap.
      # @return [String]
      def wrap_for_nesting(source)
        nesting = Pry::Code.from_file(method_object.source_file).nesting_at(method_object.source_line)

        (nesting + [source] + nesting.map{ "end" } + [""]).join("\n")
      rescue Pry::Indent::UnparseableNestingError => e
        source
      end
    end
  end
end
