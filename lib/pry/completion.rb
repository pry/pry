# taken from irb

require "readline"

class Pry

  # Implements tab completion for Readline in Pry
  module InputCompleter

    if Readline.respond_to?("basic_word_break_characters=")
      Readline.basic_word_break_characters = " \t\n\"\\'`><=;|&{("
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
    def self.build_completion_proc(target, pry=nil, commands=[""])
      proc do |input|

        # if there are multiple contexts e.g. cd 1/2/3
        # get new target for 1/2 and find candidates for 3
        path, input = build_path(input)

        unless path.call.empty?
          target, _ = Pry::Helpers::BaseHelpers.context_from_object_path(path.call, pry) 
          target = target.last
        end
        
        begin
          bind = target

          case input


          # Complete stdlib symbols

          when /^(\/[^\/]*\/)\.([^.]*)$/
            # Regexp
            receiver = $1
            message = Regexp.quote($2)

            candidates = Regexp.instance_methods.collect(&:to_s)
            select_message(path, receiver, message, candidates)

          when /^([^\]]*\])\.([^.]*)$/
            # Array
            receiver = $1
            message = Regexp.quote($2)

            candidates = Array.instance_methods.collect(&:to_s)
            select_message(path, receiver, message, candidates)

          when /^([^\}]*\})\.([^.]*)$/
            # Proc or Hash
            receiver = $1
            message = Regexp.quote($2)

            candidates = Proc.instance_methods.collect(&:to_s)
            candidates |= Hash.instance_methods.collect(&:to_s)
            select_message(path, receiver, message, candidates)

          when /^(:[^:.]*)$/
            # Symbol
            if Symbol.respond_to?(:all_symbols)
              sym        = Regexp.quote($1)
              candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}

              candidates.grep(/^#{sym}/)
            else
              []
            end

          when /^::([A-Z][^:\.\(]*)$/
            # Absolute Constant or class methods
            receiver = $1
            candidates = Object.constants.collect(&:to_s)
            candidates.grep(/^#{receiver}/).collect{|e| "::" + e}

          
          # Complete target symbols

          when /^([A-Z][A-Za-z0-9]*)$/
            # Constant
            message = $1
            candidates = target.eval("self.class.constants").collect(&:to_s)
            candidates.grep(/^#{message}/).collect(&path)

          when /^([A-Z].*)::([^:.]*)$/  
            # Constant or class methods
            receiver = $1
            message = Regexp.quote($2)
            begin
              candidates = eval("#{receiver}.constants.collect(&:to_s)", bind)
              candidates |= eval("#{receiver}.methods.collect(&:to_s)", bind)
            rescue RescuableException
              candidates = []
            end
            candidates.grep(/^#{message}/).collect{|e| receiver + "::" + e}

          when /^(:[^:.]+)\.([^.]*)$/
            # Symbol
            receiver = $1
            message = Regexp.quote($2)

            candidates = Symbol.instance_methods.collect(&:to_s)
            select_message(path, receiver, message, candidates)

          when /^(-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)\.([^.]*)$/
            # Numeric
            receiver = $1
            message = Regexp.quote($5)

            begin
              candidates = eval(receiver, bind).methods.collect(&:to_s)
            rescue RescuableException
              candidates = []
            end
            select_message(path, receiver, message, candidates)

          when /^(-?0x[0-9a-fA-F_]+)\.([^.]*)$/#
            # Numeric(0xFFFF)
            receiver = $1
            message = Regexp.quote($2)

            begin
              candidates = eval(receiver, bind).methods.collect(&:to_s)
            rescue RescuableException
              candidates = []
            end
            select_message(path, receiver, message, candidates)

          when /^(\$[^.]*)$/
            # Global variables
            regmessage = Regexp.new(Regexp.quote($1))
            candidates = global_variables.collect(&:to_s).grep(regmessage)

          when /^([^."].*)\.([^.]*)$/  
            # Variable
            receiver = $1
            message = Regexp.quote($2)

            gv = eval("global_variables", bind).collect(&:to_s)
            lv = eval("local_variables", bind).collect(&:to_s)
            cv = eval("self.class.constants", bind).collect(&:to_s)

            if (gv | lv | cv).include?(receiver) or /^[A-Z]/ =~ receiver && /\./ !~ receiver
              # foo.func and foo is local var. OR
              # Foo::Bar.func
              begin
                candidates = eval("#{receiver}.methods", bind).collect(&:to_s)
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

                # jruby doesn't always provide #instance_methods() on each
                # object.
                if m.respond_to?(:instance_methods)
                  candidates.concat m.instance_methods(false).collect(&:to_s)
                end
              }
              candidates.sort!
              candidates.uniq!
            end
            select_message(path, receiver, message, candidates)

          when /^\.([^.]*)$/
            # Unknown(maybe String)
            receiver = ""
            message = Regexp.quote($1)

            candidates = String.instance_methods(true).collect(&:to_s)
            select_message(path, receiver, message, candidates)

          else

            candidates = eval(
              "methods | private_methods | local_variables | " \
                "self.class.constants | instance_variables",
              bind
            ).collect(&:to_s)

            if eval("respond_to?(:class_variables)", bind)
              candidates += eval("class_variables", bind).collect(&:to_s)
            end
            candidates = (candidates|ReservedWords|commands).grep(/^#{Regexp.quote(input)}/)
            candidates.collect(&path)
          end
        rescue RescuableException
          []
        end
      end
    end

    def self.select_message(path, receiver, message, candidates)
      candidates.grep(/^#{message}/).collect do |e|
        case e
        when /^[a-zA-Z_]/
          path.call(receiver + "." + e)
        when /^[0-9]/
        when *Operators
          #receiver + " " + e
        end
      end
    end

    def self.build_path(input)
      return proc {|input| input.to_s }, input if input[/\/\./]

      trailing_slash = input[-1] == '/'
      contexts = input.chomp('/').split(/\//)
      input = contexts[-1]

      path = proc do |input| 
        p = contexts[0..-2].push(input).join('/')
        p += '/' if trailing_slash && !input.nil?
        p
      end

      return path, input
    end
  end
end

