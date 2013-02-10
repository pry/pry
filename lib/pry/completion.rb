# taken from irb

class Pry

  module BondCompleter

    def self.build_completion_proc(target, pry=nil, commands=[""])
      if !@started
        @started = true
        start
      end

      Pry.current[:pry] = pry
      proc{ |*a| Bond.agent.call(*a) }
    end

    def self.start
      Bond.start(:eval_binding => lambda{ Pry.current[:pry].current_context })
      Bond.complete(:on => /\A/) do |input|
        Pry.commands.complete(input.line,
                             :pry_instance => Pry.current[:pry],
                             :target       => Pry.current[:pry].current_context,
                             :command_set  => Pry.current[:pry].commands)
      end
    end

  end

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

        # We silence warnings here or Ruby 1.8 cries about "multiple values for
        # block 0 for 1".
        Helpers::BaseHelpers.silence_warnings do
          unless path.call.empty?
            target = begin
              ctx = Helpers::BaseHelpers.context_from_object_path(path.call, pry)
              ctx.first
            rescue Pry::CommandError
              []
            end
            target = target.last
          end
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

            begin
              context = target.eval("self")
              context = context.class unless context.respond_to? :constants
              candidates = context.constants.collect(&:to_s)
            rescue
              candidates = []
            end
            candidates = candidates.grep(/^#{message}/).collect(&path)

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
      candidates.grep(/^#{message}/).collect { |e|
        case e
        when /^[a-zA-Z_]/
          path.call(receiver + "." + e)
        when /^[0-9]/
        when *Operators
          #receiver + " " + e
        end
      }.compact
    end

    # build_path seperates the input into two parts: path and input.
    # input is the partial string that should be completed
    # path is a proc that takes an input and builds a full path.
    def self.build_path(input)

      # check to see if the input is a regex
      return proc {|input| input.to_s }, input if input[/\/\./]

      trailing_slash = input.end_with?('/')
      contexts = input.chomp('/').split(/\//)
      input = contexts[-1]

      path = Proc.new do |input|
        p = contexts[0..-2].push(input).join('/')
        p += '/' if trailing_slash && !input.nil?
        p
      end

      return path, input
    end
  end
end
