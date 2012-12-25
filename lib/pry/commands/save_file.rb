class Pry
  class Command::SaveFile < Pry::ClassCommand
    match 'save-file'
    group 'Input and Output'
    description 'Export to a file using content from the REPL.'

    banner <<-USAGE
      Usage: save-file [OPTIONS] [FILE]
      Save REPL content to a file.
      e.g: save-file -m my_method -m my_method2 ./hello.rb
      e.g: save-file -i 1..10 ./hello.rb --append
      e.g: save-file -k show-method ./my_command.rb
      e.g: save-file -f sample_file --lines 2..10 ./output_file.rb
    USAGE

    attr_accessor :content
    attr_accessor :file_name

    def setup
      self.content = ""
    end

    def convert_to_range(n)
      if !n.is_a?(Range)
        (n..n)
      else
        n
      end
    end

    def options(opt)
      opt.on :m, :method, "Save a method's source.", :argument => true do |meth_name|
        meth = get_method_or_raise(meth_name, target, {})
        self.content << meth.source
      end
      opt.on :c, :class, "Save a class's source.", :argument => true do |class_name|
        mod = Pry::WrappedModule.from_str(class_name, target)
        self.content << mod.source
      end
      opt.on :k, :command, "Save a command's source.", :argument => true do |command_name|
        command = find_command(command_name)
        block = Pry::Method.new(command.block)
        self.content << block.source
      end
      opt.on :f, :file, "Save a file.", :argument => true do |file|
        self.content << File.read(File.expand_path(file))
      end
      opt.on :l, :lines, "Only save a subset of lines.", :optional_argument => true, :as => Range, :default => 1..-1
      opt.on :o, :out, "Save entries from Pry's output result history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1 do |range|
        range = convert_to_range(range)

        range.each do |v|
          self.content << Pry.config.gist.inspecter.call(_pry_.output_array[v])
        end

        self.content << "\n"
      end
      opt.on :i, :in, "Save entries from Pry's input expression history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1 do |range|
        input_expressions = _pry_.input_array[range] || []
        Array(input_expressions).each { |v| self.content << v }
      end
      opt.on :a, :append, "Append to the given file instead of overwriting it."
    end

    def process
      if args.empty?
        raise CommandError, "Must specify a file name."
      end

      self.file_name = File.expand_path(args.first)

      save_file
    end

    def save_file
      if self.content.empty?
        raise CommandError, "Found no code to save."
      end

      File.open(file_name, mode) do |f|
        if opts.present?(:lines)
          f.puts restrict_to_lines(content, opts[:l])
        else
          f.puts content
        end
      end
      output.puts "#{file_name} successfully saved"
    end

    def mode
      if opts.present?(:append)
        "a"
      else
        "w"
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::SaveFile)
end
