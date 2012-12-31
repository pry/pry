require 'forwardable'

class Pry
  class Command::Edit
    class ExceptionPatcher
      extend Forwardable

      def_delegators :@edit_context, :state, :_pry_

      def initialize(edit_context)
        @edit_context = edit_context
      end

      # perform the patch
      def perform_patch
        file_name, line = ContextLocator.new(@edit_context).file_and_line
        lines = state.dynamical_ex_file || File.read(file_name)

        source = Pry::Editor.edit_tempfile_with_content(lines)
        _pry_.evaluate_ruby source
        state.dynamical_ex_file = source.split("\n")
      end
    end
  end
end
