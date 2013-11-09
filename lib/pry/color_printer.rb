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
        [highlight_object_literal(str), width]
      else
        [CodeRay.scan(str, :ruby).term, width]
      end
    end

    def pp(obj)
      super
    rescue => e
      raise if e.is_a? Pry::Pager::StopPaging

      # Read the class name off of the singleton class to provide a default
      # inspect.
      eig    = class << obj; self; end
      klass  = Pry::Method.safe_send(eig, :ancestors).first
      obj_id = obj.__id__.to_s(16) rescue 0
      str    = "#<#{klass}:0x#{obj_id}>"

      text(Pry.color ? highlight_object_literal(str) : str)
    end

    private

    def highlight_object_literal(object_literal)
      "#{OBJ_COLOR}#{object_literal}\e[0m"
    end
  end
end
