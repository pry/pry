class Pry
  class << self
    # Convert the given object into an instance of `Pry::Code`, if it isn't
    # already one.
    #
    # @param [Code, Method, UnboundMethod, Proc, Pry::Method, String, Array,
    #   IO] obj
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

  # `Pry::Code` is a class that encapsulates lines of source code and their
  # line numbers and formats them for terminal output. It can read from a file
  # or method definition or be instantiated with a `String` or an `Array`.
  #
  # In general, the formatting methods in `Code` return a new `Code` object
  # which will format the text as specified when `#to_s` is called. This allows
  # arbitrary chaining of formatting methods without mutating the original
  # object.
  class Code
    class << self
      # Instantiate a `Code` object containing code loaded from a file or
      # Pry's line buffer.
      #
      # @param [String] fn The name of a file, or "(pry)".
      # @param [Symbol] code_type (:ruby) The type of code the file contains.
      # @return [Code]
      def from_file(fn, code_type=nil)
        if fn == Pry.eval_path
          f = Pry.line_buffer.drop(1)
        else
          if File.readable?(fn)
            f = File.open(fn, 'r')
            code_type = type_from_filename(fn)
          else
            raise CommandError, "Cannot open #{fn.inspect} for reading."
          end
        end
        new(f, 1, code_type || :ruby)
      ensure
        f.close if f.respond_to?(:close)
      end

      # Instantiate a `Code` object containing code extracted from a
      # `::Method`, `UnboundMethod`, `Proc`, or `Pry::Method` object.
      #
      # @param [::Method, UnboundMethod, Proc, Pry::Method] meth The method
      #   object.
      # @param [Fixnum, nil] The line number to start on, or nil to use the
      #   method's original line numbers.
      # @return [Code]
      def from_method(meth, start_line=nil)
        meth = Pry::Method(meth)
        start_line ||= meth.source_line || 1
        new(meth.source, start_line, meth.source_type)
      end

      protected
        # Guess the CodeRay type of a file from its extension, or nil if
        # unknown.
        #
        # @param [String] filename
        # @return [Symbol, nil]
        def type_from_filename(filename)
          map = {
            %w(.c .h) => :c,
            %w(.cpp .hpp .cc .h cxx) => :cpp,
            %w(.rb .ru .irbrc .gemspec .pryrc) => :ruby,
            %w(.py) => :python,
            %w(.diff) => :diff,
            %w(.css) => :css,
            %w(.html) => :html,
            %w(.yaml .yml) => :yaml,
            %w(.xml) => :xml,
            %w(.php) => :php,
            %w(.js) => :javascript,
            %w(.java) => :java,
            %w(.rhtml) => :rhtml,
            %w(.json) => :json
          }

          _, type = map.find do |k, _|
            k.any? { |ext| ext == File.extname(filename) }
          end

          type
        end
    end

    attr_accessor :code_type

    # Instantiate a `Code` object containing code from the given `Array`,
    # `String`, or `IO`. The first line will be line 1 unless specified
    # otherwise. If you need non-contiguous line numbers, you can create an
    # empty `Code` object and then use `#push` to insert the lines.
    #
    # @param [Array<String>, String, IO] lines
    # @param [Fixnum?] (1) start_line
    # @param [Symbol?] (:ruby) code_type
    def initialize(lines=[], start_line=1, code_type=:ruby)
      if lines.is_a? String
        lines = lines.lines
      end

      @lines = lines.each_with_index.map { |l, i| [l.chomp, i + start_line.to_i] }
      @code_type = code_type
    end

    # Append the given line. `line_num` is one more than the last existing
    # line, unless specified otherwise.
    #
    # @param [String] line
    # @param [Fixnum?] line_num
    # @return [String] The inserted line.
    def push(line, line_num=nil)
      line_num = @lines.last.last + 1 unless line_num
      @lines.push([line.chomp, line_num])
      line
    end
    alias << push

    # Filter the lines using the given block.
    #
    # @yield [line]
    # @return [Code]
    def select(&blk)
      alter do
        @lines = @lines.select(&blk)
      end
    end

    # Remove all lines that aren't in the given range, expressed either as a
    # `Range` object or a first and last line number (inclusive). Negative
    # indices count from the end of the array of lines.
    #
    # @param [Range, Fixnum] start_line
    # @param [Fixnum?] end_line
    # @return [Code]
    def between(start_line, end_line=nil)
      return self unless start_line

      if start_line.is_a? Range
        end_line = start_line.last
        end_line -= 1 if start_line.exclude_end?

        start_line = start_line.first
      else
        end_line ||= start_line
      end

      if start_line > 0
        start_idx = @lines.index { |l| l.last >= start_line } || @lines.length
      else
        start_idx = start_line
      end

      if end_line > 0
        end_idx = (@lines.index { |l| l.last > end_line } || 0) - 1
      else
        end_idx = end_line
      end

      alter do
        @lines = @lines[start_idx..end_idx] || []
      end
    end

    # Remove all lines except for the `lines` up to and excluding `line_num`.
    #
    # @param [Fixnum] line_num
    # @param [Fixnum] (1) lines
    # @return [Code]
    def before(line_num, lines=1)
      return self unless line_num

      select do |l, ln|
        ln >= line_num - lines && ln < line_num
      end
    end

    # Remove all lines except for the `lines` on either side of and including
    # `line_num`.
    #
    # @param [Fixnum] line_num
    # @param [Fixnum] (1) lines
    # @return [Code]
    def around(line_num, lines=1)
      return self unless line_num

      select do |l, ln|
        ln >= line_num - lines && ln <= line_num + lines
      end
    end

    # Remove all lines except for the `lines` after and excluding `line_num`.
    #
    # @param [Fixnum] line_num
    # @param [Fixnum] (1) lines
    # @return [Code]
    def after(line_num, lines=1)
      return self unless line_num

      select do |l, ln|
        ln > line_num && ln <= line_num + lines
      end
    end

    # Remove all lines that don't match the given `pattern`.
    #
    # @param [Regexp] pattern
    # @return [Code]
    def grep(pattern)
      return self unless pattern
      pattern = Regexp.new(pattern)

      select do |l, ln|
        l =~ pattern
      end
    end

    # Format output with line numbers next to it, unless `y_n` is falsy.
    #
    # @param [Boolean?] (true) y_n
    # @return [Code]
    def with_line_numbers(y_n=true)
      alter do
        @with_line_numbers = y_n
      end
    end

    # Format output with a marker next to the given `line_num`, unless `line_num`
    # is falsy.
    #
    # @param [Fixnum?] (1) line_num
    # @return [Code]
    def with_marker(line_num=1)
      alter do
        @with_marker     = !!line_num
        @marker_line_num = line_num
      end
    end

    # Format output with the specified number of spaces in front of every line,
    # unless `spaces` is falsy.
    #
    # @param [Fixnum?] (0) spaces
    # @return [Code]
    def with_indentation(spaces=0)
      alter do
        @with_indentation = !!spaces
        @indentation_num  = spaces
      end
    end

    # @return [String]
    def inspect
      Object.instance_method(:to_s).bind(self).call
    end

    # Based on the configuration of the object, return a formatted String
    # representation.
    #
    # @return [String]
    def to_s
      lines = @lines.map(&:dup)

      if Pry.color
        lines.each do |l|
          l[0] = CodeRay.scan(l[0], @code_type).term
        end
      end

      if @with_line_numbers
        max_width = lines.last.last.to_s.length if lines.length > 0
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

    # Return an unformatted String of the code.
    #
    # @return [String]
    def raw
      @lines.map(&:first).join("\n") + "\n"
    end

    # Return the number of lines stored.
    #
    # @return [Fixnum]
    def length
      @lines ? @lines.length : 0
    end

    # Two `Code` objects are equal if they contain the same lines with the same
    # numbers. Otherwise, call `to_s` and `chomp` and compare as Strings.
    #
    # @param [Code, Object] other
    # @return [Boolean]
    def ==(other)
      if other.is_a?(Code)
        @other_lines = other.instance_variable_get(:@lines)
        @lines.each_with_index.all? do |(l, ln), i|
          l == @other_lines[i].first && ln == @other_lines[i].last
        end
      else
        to_s.chomp == other.to_s.chomp
      end
    end

    # Forward any missing methods to the output of `#to_s`.
    def method_missing(name, *args, &blk)
      to_s.send(name, *args, &blk)
    end
    undef =~

    protected
      # An abstraction of the `dup.instance_eval` pattern used throughout this
      # class.
      def alter(&blk)
        dup.tap { |o| o.instance_eval(&blk) }
      end
  end
end
