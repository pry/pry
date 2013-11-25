class Pry
  class Command::Cat
    class FileFormatter < AbstractFormatter
      attr_accessor :file_with_embedded_line
      attr_accessor :opts
      attr_accessor :_pry_

      def initialize(file_with_embedded_line, _pry_, opts)
        @file_with_embedded_line = file_with_embedded_line
        @opts = opts
        @_pry_ = _pry_
        @code_from_file = Pry::Code.from_file(file_name)
      end

      def format
        raise CommandError, "Must provide a filename, --in, or --ex." if !file_with_embedded_line

        set_file_and_dir_locals(file_name, _pry_, _pry_.current_context)
        decorate(@code_from_file)
      end

      private

      def file_and_line
        file_name, line_num = file_with_embedded_line.split(':')

        [file_name, line_num ? line_num.to_i : nil]
      end

      def file_name
        file_and_line.first
      end

      def line_number
        file_and_line.last
      end

      def code_window_size
        Pry.config.default_window_size || 7
      end

      def decorate(content)
        line_number ? super.around(line_number, code_window_size) : super
      end

      def code_type
        opts[:type] || detect_code_type_from_file(file_name)
      end

      def detect_code_type_from_file(file_name)
        code_type = @code_from_file.code_type
        
        if code_type == :unknown
          name, ext = File.basename(file_name).split('.', 2)
          case name
          when "Rakefile", "Gemfile"
            :ruby
          else
            :text
          end
        else
          code_type
        end
      end
    end
  end
end
