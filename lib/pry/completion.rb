# taken from irb

require "readline"

class Pry

  # Implements tab completion for Readline in Pry
  module InputCompleter

    if Readline.respond_to?("basic_word_break_characters=")
      Readline.basic_word_break_characters= " \t\n\"\\'`><=;|&{("
    end

    Readline.completion_append_character = nil

    ReservedWords = [
      "BEGIN", "END",
      "alias", "and",
      "begin", "break",
      "case", "class",
      "def", "defined", "do",
      "else", "elsif", "end", "ensure",
      "false", "for",
      "if", "in",
      "module",
      "next", "nil", "not",
      "or",
      "redo", "rescue", "retry", "return",
      "self", "super",
      "then", "true",
      "undef", "unless", "until",
      "when", "while",
      "yield" ]

    Operators = [
      "%", "&", "*", "**", "+",  "-",  "/",
      "<", "<<", "<=", "<=>", "==", "===", "=~", ">", ">=", ">>",
      "[]", "[]=", "^", "!", "!=", "!~"
    ]

    # Return a new completion proc for use by Readline.
    # @param [Binding] target The current binding context.
    # @param [Array<String>] commands The array of Pry commands.
    def self.build_completion_proc(target, commands=[""])
      proc do |input|
        bind = target

        case input
        when /^(\/[^\/]*\/)\.([^.]*)$/
          # Regexp
          receiver = $1
          message = Regexp.quote($2)

          candidates = Regexp.instance_methods.collect{|m| m.to_s}
          select_message(receiver, message, candidates)

        when /^([^\]]*\])\.([^.]*)$/
          # Array
          receiver = $1
          message = Regexp.quote($2)

          candidates = Array.instance_methods.collect{|m| m.to_s}
          select_message(receiver, message, candidates)

        when /^([^\}]*\})\.([^.]*)$/
          # Proc or Hash
          receiver = $1
          message = Regexp.quote($2)

          candidates = Proc.instance_methods.collect{|m| m.to_s}
          candidates |= Hash.instance_methods.collect{|m| m.to_s}
          select_message(receiver, message, candidates)

        when /^(:[^:.]*)$/
          # Symbol
          if Symbol.respond_to?(:all_symbols)
            sym = $1
            candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
            candidates.grep(/^#{sym}/)
          else
            []
          end

        when /^::([A-Z][^:\.\(]*)$/
          # Absolute Constant or class methods
          receiver = $1
          candidates = Object.constants.collect{|m| m.to_s}
          candidates.grep(/^#{receiver}/).collect{|e| "::" + e}

        when /^([A-Z].*)::([^:.]*)$/
          # Constant or class methods
          receiver = $1
          message = Regexp.quote($2)
          begin
            candidates = eval("#{receiver}.constants.collect{|m| m.to_s}", bind)
            candidates |= eval("#{receiver}.methods.collect{|m| m.to_s}", bind)
          rescue RescuableException
            candidates = []
          end
          candidates.grep(/^#{message}/).collect{|e| receiver + "::" + e}

        when /^(:[^:.]+)\.([^.]*)$/
          # Symbol
          receiver = $1
          message = Regexp.quote($2)

          candidates = Symbol.instance_methods.collect{|m| m.to_s}
          select_message(receiver, message, candidates)

        when /^(-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)\.([^.]*)$/
          # Numeric
          receiver = $1
          message = Regexp.quote($5)

          begin
            candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
          rescue RescuableException
            candidates = []
          end
          select_message(receiver, message, candidates)

        when /^(-?0x[0-9a-fA-F_]+)\.([^.]*)$/
          # Numeric(0xFFFF)
          receiver = $1
          message = Regexp.quote($2)

          begin
            candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
          rescue RescuableException
            candidates = []
          end
          select_message(receiver, message, candidates)

        when /^(\$[^.]*)$/
          regmessage = Regexp.new(Regexp.quote($1))
          candidates = global_variables.collect{|m| m.to_s}.grep(regmessage)

        when /^([^."].*)\.([^.]*)$/
          # variable
          receiver = $1
          message = Regexp.quote($2)

          gv = eval("global_variables", bind).collect{|m| m.to_s}
          lv = eval("local_variables", bind).collect{|m| m.to_s}
          cv = eval("self.class.constants", bind).collect{|m| m.to_s}

          if (gv | lv | cv).include?(receiver) or /^[A-Z]/ =~ receiver && /\./ !~ receiver
            # foo.func and foo is local var. OR
            # Foo::Bar.func
            begin
              candidates = eval("#{receiver}.methods", bind).collect{|m| m.to_s}
            rescue RescuableException
              candidates = []
            end
          else
            # func1.func2
            candidates = []
            ObjectSpace.each_object(Module){|m|
              begin
                name = m.name.to_s
              rescue RescuableException
                name = ""
              end
              next if name != "IRB::Context" and
              /^(IRB|SLex|RubyLex|RubyToken)/ =~ name
              candidates.concat m.instance_methods(false).collect{|x| x.to_s}
            }
            candidates.sort!
            candidates.uniq!
          end
          select_message(receiver, message, candidates)

        when /^\.([^.]*)$/
          # unknown(maybe String)

          receiver = ""
          message = Regexp.quote($1)

          candidates = String.instance_methods(true).collect{|m| m.to_s}
          select_message(receiver, message, candidates)

        else
          candidates = eval("methods | private_methods | local_variables | self.class.constants", bind).collect{|m| m.to_s}

          (candidates|ReservedWords|commands).grep(/^#{Regexp.quote(input)}/)
        end
      end
    end

    def self.select_message(receiver, message, candidates)
      candidates.grep(/^#{message}/).collect do |e|
      	case e
      	when /^[a-zA-Z_]/
      	  receiver + "." + e
      	when /^[0-9]/
      	when *Operators
      	  #receiver + " " + e
      	end
      end
    end
  end
end

