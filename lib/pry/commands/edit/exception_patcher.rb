class Pry
  class Command::Edit
    class ExceptionPatcher
      attr_accessor :edit_context

      def initialize(edit_context)
        @edit_context = edit_context
      end

      # perform the patch
      def perform_patch
        file_name, line = edit_context.retrieve_file_and_line
        lines = edit_context.state.dynamical_ex_file || File.read(file_name)

        source = Pry::Editor.edit_tempfile_with_content(lines)
        edit_context._pry_.evaluate_ruby source
        edit_context.state.dynamical_ex_file = source.split("\n")
      end
    end
  end
end
