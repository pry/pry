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
    Spaces = '  '.freeze

    # Array containing all the tokens that should increase the indentation
    # level.
    OpenTokens = [
      'def',
      'class',
      'module',
      '[',
      '{',
      'do',
      'if',
      'while',
      'for'
    ]

    # Collection of tokens that decrease the indentation level.
    ClosingTokens = ['end', ']', '}']

    # Collection of token types that should be ignored. Without this list
    # keywords such as "class" inside strings would cause the code to be
    # indented incorrectly.
    IgnoreTokens = [:space, :content, :string, :delimiter]

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
      output = ''

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
          elsif OpenTokens.include?(token)
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
  end # Indent
end # Pry
