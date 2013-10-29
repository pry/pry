# PP subclass for streaming inspect output in color.
class Pry
  class ColorPrinter < ::PP
    OBJ_COLOR = begin
      code = CodeRay::Encoders::Terminal::TOKEN_COLORS[:keyword]
      if code.start_with? "\e"
        code
      else
        "\e[0m\e[0;#{code}m"
      end
    end

    def self.pp(obj, out = $>, width = 79)
      q = ColorPrinter.new(out, width)
      q.guard_inspect_key { q.pp obj }
      q.flush
      out << "\n"
    end

    def text(str, width = str.length)
      super *if !Pry.color
        [str, width]
      # Don't recolorize output with color [Issue #751]
      elsif str.include?("\e[")
        ["#{str}\e[0m", width]
      elsif str.start_with?('#<') || str == '=' || str == '>'
        ["#{OBJ_COLOR}#{str}\e[0m", width]
      else
        [CodeRay.scan(str, :ruby).term, width]
      end
    end
  end
end
