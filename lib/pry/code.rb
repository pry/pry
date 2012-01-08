class Pry
  class << self
    def Code(obj)
      case obj
      when Code
        obj
      when ::Method, UnboundMethod, Proc, Pry::Method
        Code.from_method(obj)
      else
        Code.new(obj)
      end
    end
  end

  class Code
    class << self
      # Instantiate a `Code` object containing code loaded from a file or
      # Pry's line buffer.
      # @param [String] fn The name of a file, or "(pry)".
      # @param [Symbol] code_type (:ruby) The type of code the file contains.
      # @return [Code]
      def from_file(fn, code_type=:ruby)
        if fn == Pry.eval_path
          f = Pry.line_buffer.drop(1)
        else
          if File.readable?(fn)
            f = File.open(fn, 'r')
          else
            raise CommandError, "Cannot open #{fn.inspect} for reading."
          end
        end
        new(f, 1, code_type)
      ensure
        f.close if f.respond_to?(:close)
      end

      # Instantiate a `Code` object containing code extracted from a
      # `::Method`, `UnboundMethod`, `Proc`, or `Pry::Method` object.
      # @param [::Method, UnboundMethod, Proc, Pry::Method] meth The method object.
      # @param [Fixnum, nil] The line number to start on, or nil to use the
      #   method's original line numbers.
      # @return [Code]
      def from_method(meth, start_line=nil)
        meth = Pry::Method(meth)
        start_line ||= meth.source_line || 1
        new(meth.source, start_line, meth.source_type)
      end
    end

    attr_accessor :code_type

    # @param [Array<String>, String, IO] lines
    # @param [Fixnum?] (1) start_line
    # @param [Symbol?] (:ruby) code_type
    def initialize(lines=[], start_line=1, code_type=:ruby)
      if lines.is_a? String
        lines = lines.lines
      end

      @lines = lines.each_with_index.map { |l, i| [l.chomp, i + start_line] }
      @code_type = code_type
    end

    # @param [String] line
    # @param [Fixnum?] line_num
    def push(line, line_num=nil)
      line_num = @lines.last.last + 1 unless line_num

      @lines.push([line, line_num])
      nil
    end
    alias << push

    def select(&blk)
      dup.instance_eval do
        @lines = @lines.select(&blk)
        self
      end
    end

    def before(line_num, lines=1)
      return self unless line_num
      select { |l, ln| ln >= line_num - lines && ln < line_num }
    end

    def between(start_line, end_line=nil)
      return self unless start_line

      if start_line.is_a? Range
        end_line   = start_line.last
        start_line = start_line.first
      else
        end_line ||= start_line
      end

      start_line -= 1 unless start_line < 1
      end_line   -= 1 unless end_line   < 1
      range = start_line..end_line

      dup.instance_eval do
        @lines = @lines[range] || []
        self
      end
    end

    def around(line_num, lines=1)
      return self unless line_num
      select { |l, ln| ln >= line_num - lines && ln <= line_num + lines }
    end

    def after(line_num, lines=1)
      return self unless line_num
      select { |l, ln| ln > line_num && ln <= line_num + lines }
    end

    def grep(pattern)
      return self unless pattern
      select { |l, ln| l =~ pattern }
    end

    # @param [Symbol?] color
    # @return [String]
    def with_line_numbers(y_n=true)
      dup.instance_eval do
        @with_line_numbers = y_n
        self
      end
    end

    def with_marker(line_num=1)
      dup.instance_eval do
        @with_marker     = !!line_num
        @marker_line_num = line_num
        self
      end
    end

    def with_indentation(spaces=0)
      dup.instance_eval do
        @with_indentation = !!spaces
        @indentation_num  = spaces
        self
      end
    end

    # @return [String]
    def inspect
      Object.instance_method(:to_s).bind(self).call
    end

    # @return [String]
    def to_s
      lines = @lines.map(&:dup)

      if Pry.color
        lines.each do |l|
          l[0] = CodeRay.scan(l[0], @code_type).term
        end
      end

      if @with_line_numbers
        max_width = @lines.last.last.to_s.length if @lines.length > 0
        lines.each do |l|
          padded_line_num = l[1].to_s.rjust(max_width)
          l[0] = "#{Pry::Helpers::Text.blue(padded_line_num)}: #{l[0]}"
        end
      end

      if @with_marker
        lines.each do |l|
          if l[1] == @marker_line_num
            l[0] = " => #{l[0]}"
          else
            l[0] = "    #{l[0]}"
          end
        end
      end

      if @with_indentation
        lines.each do |l|
          l[0] = "#{' ' * @indentation_num}#{l[0]}"
        end
      end

      lines.map { |l| "#{l.first}\n" }.join
    end

    def method_missing(name, *args, &blk)
      to_s.send(name, *args, &blk)
    end
  end
end
