require 'forwardable'

class Pry
  class Command::Edit
    class ContextLocator
      extend Forwardable

      def_delegators :@edit_context, :code_object, :target, :_pry_, :opts, :args

      def initialize(edit_context)
        @edit_context = edit_context
      end

      def file_and_line
        file_name, line = if opts.present?(:ex)
                            file_and_line_for_exception
                          elsif opts.present?(:current)
                            current_file_and_line
                          else
                            object_file_and_line
                          end

        [file_name, opts.present?(:line) ? opts[:l].to_i : line]
      end

      private

      def file_and_line_for_exception
        raise CommandError, "No exception found." if _pry_.last_exception.nil?

        file_name, line = _pry_.last_exception.bt_source_location_for(opts[:ex].to_i)
        raise CommandError, "Exception has no associated file." if file_name.nil?
        raise CommandError, "Cannot edit exceptions raised in REPL." if Pry.eval_path == file_name

        file_name = RbxPath.convert_path_to_full(file_name) if RbxPath.is_core_path?(file_name)

        [file_name, line]
      end

      def current_file_and_line
        [target.eval("__FILE__"), target.eval("__LINE__")]
      end

      def object_file_and_line
        if code_object
          [code_object.source_file, code_object.source_line]
        else
          # break up into file:line
          file_name = File.expand_path(args.first)
          line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
          [file_name, line]
        end
      end
    end
  end
end
