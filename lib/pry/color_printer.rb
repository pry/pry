require 'pp'

# PP subclass for streaming inspect output in color.
class Pry
  class ColorPrinter < ::PP
    Pry::SyntaxHighlighter.overwrite_coderay_comment_token!

    OBJ_COLOR = begin
      code = Pry::SyntaxHighlighter.keyword_token_color
      if code.start_with? "\e"
        code
      else
        "\e[0m\e[0;#{code}m"
      end
    end

    def self.pp(obj, out = $DEFAULT_OUTPUT, width = 79, newline = "\n")
      q = ColorPrinter.new(out, width, newline)
      q.guard_inspect_key { q.pp obj }
      q.flush
      out << "\n"
    end

    def text(str, width = str.length)
      # Don't recolorize output with color [Issue #751]
      if str.include?("\e[")
        super "#{str}\e[0m", width
      elsif str.start_with?('#<') || str == '=' || str == '>'
        super highlight_object_literal(str), width
      else
        super(SyntaxHighlighter.highlight(str), width)
      end
    end

    def pp(obj)
      if obj.is_a?(String)
        # Avoid calling Ruby 2.4+ String#pretty_print that prints multiline
        # Strings prettier
        text(obj.inspect)
      else
        super
      end
    rescue StandardError => e
      raise if e.is_a? Pry::Pager::StopPaging

      begin
        str = obj.inspect
      rescue StandardError
        # Read the class name off of the singleton class to provide a default
        # inspect.
        singleton = class << obj; self; end
        ancestors = Pry::Method.safe_send(singleton, :ancestors)
        klass  = ancestors.reject { |k| k == singleton }.first
        obj_id = begin
                   obj.__id__.to_s(16)
                 rescue StandardError
                   0
                 end
        str    = "#<#{klass}:0x#{obj_id}>"
      end

      text highlight_object_literal(str)
    end

    private

    def highlight_object_literal(object_literal)
      "#{OBJ_COLOR}#{object_literal}\e[0m"
    end
  end
end
