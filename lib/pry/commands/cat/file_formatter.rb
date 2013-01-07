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
      end

      def format
        raise CommandError, "Must provide a filename, --in, or --ex." if !file_with_embedded_line

        set_file_and_dir_locals(file_name, _pry_, _pry_.current_context)
        decorate(Pry::Code.from_file(file_name))
      end

      private

      def file_and_line
        file_name, line_num = file_with_embedded_line.split(':')

        [File.expand_path(file_name), line_num ? line_num.to_i : nil]
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
        name, ext = File.basename(file_name).split('.', 2)

        if ext
          case ext
          when "py"
            :python
          when "rb", "gemspec", "rakefile", "ru", "pryrc", "irbrc"
            :ruby
          when "js"
            return :javascript
          when "yml", "prytheme"
            :yaml
          when "groovy"
            :groovy
          when "c"
            :c
          when "cpp"
            :cpp
          when "java"
            :java
          else
            :text
          end
        else
          case name
          when "Rakefile", "Gemfile"
            :ruby
          else
            :text
          end
        end
      end
    end
  end
end
