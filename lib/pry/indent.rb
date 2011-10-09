require 'coderay'

class Pry
  ##
  # Pry::Indent is a class that can be used to indent a number of lines
  # containing Ruby code similar as to how IRB does it (but better). The class
  # works by tokenizing a string using CodeRay and then looping over those
  # tokens. Based on the tokens in a line of code that line (or the next one)
  # will be indented or un-indented by 2 spaces.
  #
  # @author Yorick Peterse
  # @since  04-10-2011
  #
  class Indent
    # Array containing all the indentation levels.
    attr_reader :stack

    # The amount of spaces to insert for each indent level.
    Spaces = '  '

    # Hash containing all the tokens that should increase the indentation
    # level. The keys of this hash are open tokens, the values the matching
    # tokens that should prevent a line from being indented if they appear on
    # the same line.
    OpenTokens = {
      'def'    => 'end',
      'class'  => 'end',
      'module' => 'end',
      'do'     => 'end',
      'if'     => 'end',
      'while'  => 'end',
      'for'    => 'end',
      '['      => ']',
      '{'      => '}',
      '('      => ')'
    }

    # Collection of tokens that decrease the indentation level.
    ClosingTokens = ['end', ']', '}']

    # Collection of token types that should be ignored. Without this list
    # keywords such as "class" inside strings would cause the code to be
    # indented incorrectly.
    IgnoreTokens = [:space, :content, :string, :delimiter, :method, :ident]

    # Tokens that indicate the end of a statement (i.e. that, if they appear
    # directly before an "if" indicates that that if applies to the same line,
    # not the next line)
    EndOfStatementTokens = IgnoreTokens + [:regexp, :integer, :float]

    # Collection of tokens that should only increase the indentation level of
    # the next line.
    OpenTokensNext = ['else', 'elsif']

    ##
    # Creates a new instance of the class and starts with a fresh stack. The
    # stack is used to keep track of the indentation level for each line of
    # code.
    #
    # @author Yorick Peterse
    # @since  05-10-2011
    #
    def initialize
      @stack = []
    end

    ##
    # Get rid of all indentation
    def reset
      @stack.clear
      self
    end

    ##
    # The current indentation level (number of spaces deep)
    def indent_level
      @stack.last || ''
    end

    ##
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
    # @author Yorick Peterse
    # @since  05-10-2011
    # @param  [String] input The input string to indent.
    # @return [String] The indented version of +input+.
    #
    def indent(input)
      output      = ''
      open_tokens = OpenTokens.keys
      prefix = indent_level

      input.lines.each do |line|

        tokens = CodeRay.scan(line, :ruby)

        before, after = indentation_delta(tokens, prefix)

        prefix.sub!(Spaces * before, '')
        output += prefix + line.strip + "\n"
        prefix += Spaces * after
      end

      @stack = [prefix]

      return output.gsub(/\s+$/, '')
    end

    ##
    # Based on a set of tokens and an open token this method will determine if
    # a line has to be indented or not. Perhaps not the most efficient way of
    # doing it so if you feel it can be improved patches are more than welcome
    # :).
    #
    # @author Yorick Peterse
    # @since  08-10-2011
    # @param  [Array] tokens A list of tokens to scan.
    # @param  [String] open_token The token who's closing token may or may not
    #  be included in the list of tokens.
    # @return [Boolean]
    #
    def indentation_delta(tokens, open_token)
      closing = OpenTokens[open_token]
      open    = OpenTokens.keys

      @useful_stack ||= []
      seen_for = false
      last_token, last_kind = [nil, nil]

      depth = 0
      before, after = [0, 0]

      # If the list of tokens contains a matching closing token the line should
      # not be indented (and thus we should return true).
      tokens.each do |token, kind|

        is_singleline_if = (token == "if" || token == "while") && end_of_statement?(last_token, last_kind)
        last_token, last_kind = token, kind unless kind == :space

        next if IgnoreTokens.include?(kind)

        # handle the optional "do" on for statements.
        seen_for ||= token == "for"

        if OpenTokens.keys.include?(token) && (token != "do" || !seen_for) && !is_singleline_if
          @useful_stack << token
          depth += 1
          after += 1
        elsif token == OpenTokens[@useful_stack.last]
          @useful_stack.pop
          depth -= 1
          if depth < 0
            before += 1
          else
            after -= 1
          end
        elsif OpenTokensNext.include?(token)
          if depth <= 0
            before += 1
            after += 1
          end
        end
      end

      return [before, after]
    end

    # If the code just before an "if" or "while" token on a line looks like the end of a statement,
    # then we want to treat that "if" as a singleline, not multiline statement.
    def end_of_statement?(last_token, last_kind)
      (last_token =~ /^[)\]}\/]$/ || EndOfStatementTokens.include?(last_kind))
    end

    ##
    # Fix the indentation for closing tags (notably 'end'). Note that this
    # method will not work on Win32 based systems (or other systems that don't
    # have the tput command).
    #
    # @param [String] full_line The full line of input, including the prompt.
    #
    def correct_indentation(full_line)
      # The whitespace is used to "clear" the current line so existing
      # characters don't show up.
      spaces = ' ' * full_line.length

      $stdout.write(`tput sc` + `tput cuu1` + full_line + spaces + `tput rc`)
    end
  end # Indent
end # Pry
