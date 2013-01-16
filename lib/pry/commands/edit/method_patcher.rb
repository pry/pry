class Pry
  class Command::Edit
    class MethodPatcher
      attr_accessor :_pry_
      attr_accessor :code_object

      def initialize(_pry_, code_object)
        @_pry_ = _pry_
        @code_object = code_object
      end

      # perform the patch
      def perform_patch
        if code_object.alias?
          with_method_transaction do
            _pry_.evaluate_ruby patched_code
          end
        else
          _pry_.evaluate_ruby patched_code
        end
      end

      private

      def patched_code
        @patched_code ||= wrap(Pry::Editor.edit_tempfile_with_content(adjusted_lines))
      end

      # The method code adjusted so that the first line is rewritten
      # so that def self.foo --> def foo
      def adjusted_lines
        lines = code_object.source.lines.to_a
        lines[0] = definition_line_for_owner(lines.first)
        lines
      end

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
        temp_name = "__pry_#{code_object.original_name}__"
        co = code_object
        code_object.owner.class_eval do
          alias_method temp_name, co.original_name
          yield
          alias_method co.name, co.original_name
          alias_method co.original_name, temp_name
        end

      ensure
        co.send(:remove_method, temp_name) rescue nil
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
        if line =~ /^def (?:.*?\.)?#{Regexp.escape(code_object.original_name)}(?=[\(\s;]|$)/
          "def #{code_object.original_name}#{$'}"
        else
          raise CommandError, "Could not find original `def #{code_object.original_name}` line to patch."
        end
      end

      # Apply wrap_for_owner and wrap_for_nesting successively to `source`
      # @param [String] source
      # @return [String] The wrapped source.
      def wrap(source)
        wrap_for_nesting(wrap_for_owner(source))
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
        Pry.current[:pry_owner] = code_object.owner
        "Pry.current[:pry_owner].class_eval do\n#{source}\nend"
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
        nesting = Pry::Code.from_file(code_object.source_file).nesting_at(code_object.source_line)

        (nesting + [source] + nesting.map{ "end" } + [""]).join("\n")
      rescue Pry::Indent::UnparseableNestingError => e
        source
      end
    end
  end
end
