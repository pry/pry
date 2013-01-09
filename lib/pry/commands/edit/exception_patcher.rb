class Pry
  class Command::Edit
    class ExceptionPatcher
      attr_accessor :opts
      attr_accessor :_pry_
      attr_accessor :state

      def initialize(opts, _pry_, state)
        @opts = opts
        @_pry_ = _pry_
        @state = state
      end

      # perform the patch
      def perform_patch
        file_name, line = file_and_line
        lines = state.dynamical_ex_file || File.read(file_name)

        source = Pry::Editor.edit_tempfile_with_content(lines)
        _pry_.evaluate_ruby source
        state.dynamical_ex_file = source.split("\n")
      end

      def file_and_line
        raise CommandError, "No exception found." if _pry_.last_exception.nil?

        file_name, line = _pry_.last_exception.bt_source_location_for(opts[:ex].to_i)
        raise CommandError, "Exception has no associated file." if file_name.nil?
        raise CommandError, "Cannot edit exceptions raised in REPL." if Pry.eval_path == file_name

        file_name = RbxPath.convert_path_to_full(file_name) if RbxPath.is_core_path?(file_name)

        [file_name, line]
      end
    end
  end
end
