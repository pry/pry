class Pry
  Pry::Commands.create_command "save-file" do
    group 'Input and Output'
    description "Export to a file using content from the REPL."

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
    attr_accessor :file_name_parts

    def setup
      self.content = ""
      self.file_name_parts = []
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
        self.file_name_parts << meth_name
      end
      opt.on :c, :class, "Save a class's source.", :argument => true do |class_name|
        mod = Pry::WrappedModule.from_str(class_name, target)
        self.content << mod.source
        self.file_name_parts << class_name
      end
      opt.on :k, :command, "Save a command's source.", :argument => true do |command_name|
        command = find_command(command_name)
        block = Pry::Method.new(command.block)
        self.content << block.source
        self.file_name_parts << command_name
      end
      opt.on :f, :file, "Save a file.", :argument => true do |file|
        self.content << File.read(File.expand_path(file))
        self.file_name_parts << File.basename(file, File.extname(file))
      end
      opt.on :l, :lines, "Only save a subset of lines.", :optional_argument => true, :as => Range, :default => 1..-1
      opt.on :o, :out, "Save entries from Pry's output result history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1 do |range|
        range = convert_to_range(range)

        range.each do |v|
          self.content << Pry.config.gist.inspecter.call(_pry_.output_array[v])
        end

        self.content << "\n"
        self.file_name_parts << "output_history"
      end
      opt.on :i, :in, "Save entries from Pry's input expression history. Takes an index or range.", :optional_argument => true,
      :as => Range, :default => -5..-1 do |range|
        input_expressions = _pry_.input_array[range] || []
        Array(input_expressions).each { |v| self.content << v }
        self.file_name_parts << "input_history"
      end
      opt.on :a, :append, "Append to the given file instead of overwriting it."
    end

    def process
      if args.empty?
        ask_and_create_directory! unless Dir.exists?(Pry.config.save_file_path)
        generate_file_name
      else
        tmp_name = args.first
        if tmp_name == File.basename(tmp_name)
          self.file_name = File.join(Pry.config.save_file_path, tmp_name)
        else
          self.file_name = File.expand_path(tmp_name)
        end
      end

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

    def generate_file_name
      tmp_filename = self.file_name_parts.join("-")

      if File.exists?("#{File.join(Pry.config.save_file_path, tmp_filename)}.rb")
        self.file_name = "#{File.join(Pry.config.save_file_path, "#{tmp_filename}-#{Time.now.to_i}")}.rb"
      else
        self.file_name = "#{File.join(Pry.config.save_file_path, tmp_filename)}.rb"
      end
    end

    def ask_and_create_directory!
      output.puts unindent(%{
        The save-file path #{Pry.config.save_file_path} doesn't exist.
        You can edit it in Pry.config.save_file_path
        Would you like to create it ? [Y/n]
      }).strip
      yn = $stdin.gets
      if yn.strip.empty? || yn.strip.downcase == "y"
        Dir.mkdir(Pry.config.save_file_path)
      else
        raise CommandError, unindent(%{
          Your save-file path #{Pry.config.save_file_path} doesn't exist. Please create it.
        }).strip
      end
    end

    def mode
      if opts.present?(:append)
        "a"
      else
        "w"
      end
    end
  end
end
