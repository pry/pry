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
    }

    # Collection of tokens that decrease the indentation level.
    ClosingTokens = ['end', ']', '}']

    # Collection of token types that should be ignored. Without this list
    # keywords such as "class" inside strings would cause the code to be
    # indented incorrectly.
    IgnoreTokens = [:space, :content, :string, :delimiter, :method, :ident]

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
    end

    ##
    # The current indentation level (number of spaces deep)
    def indent_level
      @stack.last
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

      input.lines.each do |line|
        # Remove manually added indentation.
        line   = line.strip + "\n"
        tokens = CodeRay.scan(line, :ruby)

        unless @stack.empty?
          line = @stack[-1] + line
        end

        tokens.each do |token, kind|
          next if IgnoreTokens.include?(kind)

          if OpenTokensNext.include?(token) and @stack[-1]
            line.sub!(@stack[-1], '')
            break
          # Start token found (such as "class"). Update the stack and indent the
          # current line.
          elsif open_tokens.include?(token)
            # Skip indentation if there's a matching closing token on the same
            # line.
            next if skip_indentation?(tokens, token)

            add  = ''
            last = @stack[-1]

            # Determine the amount of spaces to add to the stack and the line.
            unless last.nil?
              add = Spaces + last
            end

            # Don't forget to update the current line.
            if @stack.empty?
              line  = add + line
              add  += Spaces
            end

            @stack.push(add)
            break
          # Stop token found. Remove the last number of spaces from the stack
          # and un-indent the current line.
          elsif ClosingTokens.include?(token)
            @stack.pop

            line = ( @stack[-1] || '' ) + line.strip + "\n"
            break
          end
        end

        output += line
      end

      return output.gsub!(/\s+$/, '')
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
    def skip_indentation?(tokens, open_token)
      closing = OpenTokens[open_token]
      open    = OpenTokens.keys
      skip    = false

      # If the list of tokens contains a matching closing token the line should
      # not be indented (and thus we should return true).
      tokens.each do |token, kind|
        next if IgnoreTokens.include?(kind)

        # Skip the indentation if we've found a matching closing token.
        if token == closing
          skip = true
        # Sometimes a line contains a matching closing token followed by another
        # open token. In this case the line *should* be indented. An example of
        # this is the following:
        #
        # [10, 15].each do |num|
        #   puts num
        # end
        #
        # Here we have an open token (the "[") as well as it's closing token
        # ("]"). However, there's also a "do" which indicates that the next
        # line *should* be indented.
        elsif open.include?(token)
          skip = false
        end
      end

      return skip
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
