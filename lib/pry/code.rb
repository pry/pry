class Pry
  class Code
    class << self
      # Instantiate a `Code` object containing code loaded from a file or
      # Pry's line buffer.
      # @param [String] fn The name of a file, or "(pry)".
      # @return [Code]
      def from_file(fn)
        if fn == Pry.eval_path
          f = Pry.line_buffer[1..-1]
        else
          if File.readable?(fn)
            f = File.open(fn, 'r')
          else
            raise CommandError, "Cannot open #{file.inspect} for reading."
          end
        end
        new(f)
      ensure
        f.close if f.respond_to?(:close)
      end
    end

    # @param [Array<String>] lines
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

    def before(line_num, lines=1)
      dup.instance_eval do
        @lines = @lines.select { |l, ln| ln >= line_num - lines && ln < line_num }
        self
      end
    end

    def around(line_num, lines=1)
      dup.instance_eval do
        @lines = @lines.select { |l, ln| ln >= line_num - lines && ln <= line_num + lines }
        self
      end
    end

    def after(line_num, lines=1)
      dup.instance_eval do
        @lines = @lines.select { |l, ln| ln > line_num && ln <= line_num + lines }
        self
      end
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

      lines.map(&:first).join("\n")
    end

    def method_missing(name, *args, &blk)
      to_s.send(name, *args, &blk)
    end
  end
end
