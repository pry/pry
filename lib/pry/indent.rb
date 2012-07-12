require 'coderay'

class Pry
  # Load io-console if possible, so that we can use $stdout.winsize.
  begin
    require 'io/console'
  rescue LoadError
  end

  ##
  # Pry::Indent is a class that can be used to indent a number of lines
  # containing Ruby code similar as to how IRB does it (but better). The class
  # works by tokenizing a string using CodeRay and then looping over those
  # tokens. Based on the tokens in a line of code that line (or the next one)
  # will be indented or un-indented by correctly.
  #
  class Indent
    include Helpers::BaseHelpers

    # @return [String] String containing the spaces to be inserted before the next line.
    attr_reader :indent_level
    
    # @return [Array<String>] The stack of open tokens.
    attr_reader :stack

    # The amount of spaces to insert for each indent level.
    SPACES = '  '

    # Hash containing all the tokens that should increase the indentation
    # level. The keys of this hash are open tokens, the values the matching
    # tokens that should prevent a line from being indented if they appear on
    # the same line.
    OPEN_TOKENS = {
      'def'    => 'end',
      'class'  => 'end',
      'module' => 'end',
      'do'     => 'end',
      'if'     => 'end',
      'unless' => 'end',
      'while'  => 'end',
      'until'  => 'end',
      'for'    => 'end',
      'case'   => 'end',
      'begin'  => 'end',
      '['      => ']',
      '{'      => '}',
      '('      => ')'
    }

    # Which tokens can either be open tokens, or appear as modifiers on
    # a single-line.
    SINGLELINE_TOKENS = %w(if while until unless rescue)

    # Collection of token types that should be ignored. Without this list
    # keywords such as "class" inside strings would cause the code to be
    # indented incorrectly.
    #
    # :pre_constant and :preserved_constant are the CodeRay 0.9.8 and 1.0.0
    # classifications of "true", "false", and "nil".
    IGNORE_TOKENS = [:space, :content, :string, :method, :ident,
                     :constant, :pre_constant, :predefined_constant]

    # Tokens that indicate the end of a statement (i.e. that, if they appear
    # directly before an "if" indicates that that if applies to the same line,
    # not the next line)
    #
    # :reserved and :keywords are the CodeRay 0.9.8 and 1.0.0 respectively
    # classifications of "super", "next", "return", etc.
    STATEMENT_END_TOKENS = IGNORE_TOKENS + [:regexp, :integer, :float, :keyword,
                                            :delimiter, :reserved]

    # Collection of tokens that should appear dedented even though they
    # don't affect the surrounding code.
    MIDWAY_TOKENS = %w(when else elsif ensure rescue)

    def initialize
      reset
    end

    # reset internal state
    def reset
      @stack = []
      @indent_level = ''
      @heredoc_queue = []
      @close_heredocs = {}
      @string_start = nil
      self
    end

    # Indents a string and returns it. This string can either be a single line
    # or multiple ones.
    #
    # @example
    #  str = <<TXT
    #  class User
    #  attr_accessor :name
    #  end
    #  TXT
    #
    #  # This would result in the following being displayed:
    #  #
    #  # class User
    #  #   attr_accessor :name
    #  # end
    #  #
    #  puts Pry::Indent.new.indent(str)
    #
    # @param  [String] input The input string to indent.
    # @return [String] The indented version of +input+.
    #
    def indent(input)
      output = ''
      prefix = indent_level

      input.lines.each do |line|

        if in_string?
          tokens = tokenize("#{open_delimiters_line}\n#{line}")
          tokens = tokens.drop_while{ |token, type| !(String === token && token.include?("\n")) }
          previously_in_string = true
        else
          tokens = tokenize(line)
          previously_in_string = false
        end

        before, after = indentation_delta(tokens)

        before.times{ prefix.sub! SPACES, '' }
        new_prefix = prefix + SPACES * after

        line = prefix + line.lstrip unless previously_in_string
        line = line.rstrip + "\n"   unless in_string?

        output += line

        prefix = new_prefix
      end

      @indent_level = prefix

      return output.gsub(/\s+$/, '')
    end

    # Get the indentation for the start of the next line.
    #
    # This is what's used between the prompt and the cursor in pry.
    #
    # @return String  The correct number of spaces
    #
    def current_prefix
      in_string? ? '' : indent_level
    end

    # Get the change in indentation indicated by the line.
    #
    # By convention, you remove indent from the line containing end tokens,
    # but add indent to the line *after* that which contains the start tokens.
    #
    # This method returns a pair, where the first number is the number of closings
    # on this line (i.e. the number of indents to remove before the line) and the
    # second is the number of openings (i.e. the number of indents to add after
    # this line)
    #
    # @param  [Array] tokens A list of tokens to scan.
    # @return [Array[Integer]]
    #
    def indentation_delta(tokens)

      # We need to keep track of whether we've seen a "for" on this line because
      # if the line ends with "do" then that "do" should be discounted (i.e. we're
      # only opening one level not two) To do this robustly we want to keep track
      # of the indent level at which we saw the for, so we can differentiate
      # between "for x in [1,2,3] do" and "for x in ([1,2,3].map do" properly
      seen_for_at = []

      # When deciding whether an "if" token is the start of a multiline statement,
      # or just the middle of a single-line if statement, we just look at the
      # preceding token, which is tracked here.
      last_token, last_kind = [nil, nil]

      # delta keeps track of the total difference from the start of each line after
      # the given token, 0 is just the level at which the current line started for
      # reference.
      remove_before, add_after = [0, 0]

      # If the list of tokens contains a matching closing token the line should
      # not be indented (and thus we should return true).
      tokens.each do |token, kind|
        is_singleline_if  = (SINGLELINE_TOKENS.include?(token)) && end_of_statement?(last_token, last_kind)
        is_optional_do = (token == "do" && seen_for_at.include?(add_after - 1))

        last_token, last_kind = token, kind unless kind == :space
        next if IGNORE_TOKENS.include?(kind)

        seen_for_at << add_after if token == "for"

        if kind == :delimiter
          track_delimiter(token)
        elsif OPEN_TOKENS.keys.include?(token) && !is_optional_do && !is_singleline_if
          @stack << token
          add_after += 1
        elsif token == OPEN_TOKENS[@stack.last]
          @stack.pop
          if add_after == 0
            remove_before += 1
          else
            add_after -= 1
          end
        elsif MIDWAY_TOKENS.include?(token)
          if add_after == 0
            remove_before += 1
            add_after += 1
          end
        end
      end

      return [remove_before, add_after]
    end

    # If the code just before an "if" or "while" token on a line looks like the end of a statement,
    # then we want to treat that "if" as a singleline, not multiline statement.
    def end_of_statement?(last_token, last_kind)
      (last_token =~ /^[)\]}\/]$/ || STATEMENT_END_TOKENS.include?(last_kind))
    end

    # Are we currently in the middle of a string literal.
    #
    # This is used to determine whether to re-indent a given line, we mustn't re-indent
    # within string literals because to do so would actually change the value of the
    # String!
    #
    # @return Boolean
    def in_string?
      !open_delimiters.empty?
    end

    # Given a string of Ruby code, use CodeRay to export the tokens.
    #
    # @param [String] string The Ruby to lex
    # @return [Array] An Array of pairs of [token_value, token_type]
    def tokenize(string)
      tokens = CodeRay.scan(string, :ruby)
      tokens = tokens.tokens.each_slice(2) if tokens.respond_to?(:tokens) # Coderay 1.0.0
      tokens.to_a
    end

    # Update the internal state about what kind of strings are open.
    #
    # Most of the complication here comes from the fact that HEREDOCs can be nested. For
    # normal strings (which can't be nested) we assume that CodeRay correctly pairs
    # open-and-close delimiters so we don't bother checking what they are.
    #
    # @param [String] token The token (of type :delimiter)
    def track_delimiter(token)
      case token
      when /^<<-(["'`]?)(.*)\\1/
        @heredoc_queue << token
        @close_heredocs[token] = /^\s*$2/
      when @close_heredocs[@heredoc_queue.first]
        @heredoc_queue.shift
      else
        if @string_start
          @string_start = nil
        else
          @string_start = token
        end
      end
    end

    # All the open delimiters, in the order that they first appeared.
    #
    # @return [String]
    def open_delimiters
      @heredoc_queue + [@string_start].compact
    end

    # Return a string which restores the CodeRay string status to the correct value by
    # opening HEREDOCs and strings.
    #
    # @return String
    def open_delimiters_line
      "puts #{open_delimiters.join(", ")}"
    end

    # Return a string which, when printed, will rewrite the previous line with
    # the correct indentation. Mostly useful for fixing 'end'.
    #
    # @param [String] prompt The user's prompt
    # @param [String] code   The code the user just typed in.
    # @param [Fixnum] overhang (0) The number of chars to erase afterwards (i.e.,
    #   the difference in length between the old line and the new one).
    # @return [String]
    def correct_indentation(prompt, code, overhang=0)
      full_line = prompt + code
      whitespace = ' ' * overhang

      _, cols = screen_size

      cols = cols.to_i
      lines = cols != 0 ? (full_line.length / cols + 1) : 1

      if Pry::Helpers::BaseHelpers.windows_ansi?
        move_up   = "\e[#{lines}F"
        move_down = "\e[#{lines}E"
      else
        move_up   = "\e[#{lines}A\e[0G"
        move_down = "\e[#{lines}B\e[0G"
      end

      "#{move_up}#{prompt}#{colorize_code(code)}#{whitespace}#{move_down}"
    end

    # Return a pair of [rows, columns] which gives the size of the window.
    #
    # If the window size cannot be determined, return nil.
    def screen_size
      [
         # io/console adds a winsize method to IO streams.
         $stdout.tty? && $stdout.respond_to?(:winsize) && $stdout.winsize,

         # Some readlines also provides get_screen_size.
         Readline.respond_to?(:get_screen_size) && Readline.get_screen_size,

         # Otherwise try to use the environment (this may be out of date due
         # to window resizing, but it's better than nothing).
         [ENV["ROWS"], ENV["COLUMNS"],

         # If the user is running within ansicon, then use the screen size
         # that it reports (same caveats apply as with ROWS and COLUMNS)
         ENV['ANSICON'] =~ /\((.*)x(.*)\)/ && [$2, $1]
        ]
      ].detect do |(_, cols)|
        cols.to_i > 0
      end
    end
  end
end
