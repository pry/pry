class Pry
  Pry::Commands.create_command "play" do
    include Pry::Helpers::DocumentationHelpers

    description "Play back a string variable or a method or a file as input."

    banner <<-BANNER
      Usage: play [OPTIONS] [--help]

      The play command enables you to replay code from files and methods as
      if they were entered directly in the Pry REPL. Default action (no
      options) is to play the provided string variable

      e.g: `play -i 20 --lines 1..3`
      e.g: `play -m Pry#repl --lines 1..-1`
      e.g: `play -f Rakefile --lines 5`

      https://github.com/pry/pry/wiki/User-Input#wiki-Play
    BANNER

    attr_accessor :content

    def setup
      self.content   = ""
    end

    def options(opt)
      opt.on :m, :method, "Play a method's source.", :argument => true do |meth_name|
        meth = get_method_or_raise(meth_name, target, {})
        self.content << meth.source
      end
      opt.on :d, :doc, "Play a method's documentation.", :argument => true do |meth_name|
        meth = get_method_or_raise(meth_name, target, {})
        text.no_color do
          self.content << process_comment_markup(meth.doc)
        end
      end
      opt.on :c, :command, "Play a command's source.", :argument => true do |command_name|
        command = find_command(command_name)
        block = Pry::Method.new(command.block)
        self.content << block.source
      end
      opt.on :f, :file, "Play a file.", :argument => true do |file|
        self.content << File.read(File.expand_path(file))
      end
      opt.on :l, :lines, "Only play a subset of lines.", :optional_argument => true, :as => Range, :default => 1..-1
      opt.on :i, :in, "Play entries from Pry's input expression history. Takes an index or range. Note this can only replay pure Ruby code, not Pry commands.", :optional_argument => true,
      :as => Range, :default => -5..-1 do |range|
        input_expressions = _pry_.input_array[range] || []
        Array(input_expressions).each { |v| self.content << v }
      end
      opt.on :o, "open", 'When used with the -m switch, it plays the entire method except the last line, leaving the method definition "open". `amend-line` can then be used to modify the method.'
    end

    def process
      perform_play
      run "show-input" unless Pry::Code.complete_expression?(eval_string)
    end

    def process_non_opt
      args.each do |arg|
        begin
          self.content << target.eval(arg)
        rescue Pry::RescuableException
          raise CommandError, "Problem when evaling #{arg}."
        end
      end
    end

    def perform_play
      process_non_opt

      if opts.present?(:lines)
        self.content = restrict_to_lines(self.content, opts[:l])
      end

      if opts.present?(:open)
        self.content = restrict_to_lines(self.content, 1..-2)
      end

      eval_string << self.content
    end
  end
end
