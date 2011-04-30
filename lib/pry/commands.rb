class Pry

  # Default commands used by Pry.
  Commands = Pry::CommandSet.new :default do
    Helpers::CommandHelpers.try_to_load_pry_doc

    command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
      output.puts "Input buffer cleared!"
      opts[:eval_string].clear
    end

    command "!pry", "Start a Pry session on current self; this even works mid-expression." do
      Pry.start(target)
    end

    # this cannot be accessed, it's just for help purposes.
    command ".<shell command>", "All text following a '.' is forwarded to the shell." do
    end

    command "hist", "Show and replay Readline history. Type `hist --help` for more info." do |*args|
      hist_array = Readline::HISTORY.to_a

      if args.empty?
        text = add_line_numbers(hist_array.join("\n"), 0)
        stagger_output(text)
        next
      end

      opts = Slop.parse(args) do |opt|
        opt.banner "Usage: hist [--replay START..END]\nView and replay history\ne.g hist --replay 2..8"
        opt.on :r, :replay, 'The line (or range of lines) to replay.', true, :as => Range
        opt.on :h, :help, 'Show this message.', :tail => true do
          output.puts opt.help
        end
      end

      next if opts.h?

      actions = Array(hist_array[opts[:replay]]).join("\n") + "\n"
      Pry.active_instance.input = StringIO.new(actions)
    end

    command "edit-method", "Edit a method. Type `edit-method --help` for more info." do |*args|
      target = target()

      opts = Slop.parse!(args) do |opts|
        opts.banner %{Usage: edit-method [OPTIONS] [METH]
Edit the method METH in an editor.
Ensure #{bold("Pry.editor")} is set to your editor of choice.
e.g: edit-method hello_method
--
}
        opts.on :M, "instance-methods", "Operate on instance methods."
        opts.on :m, :methods, "Operate on methods."
        opts.on "no-reload", "Do not automatically reload the method's file after editting."
        opts.on :n, "no-jump", "Do not fast forward editor to first line of method."
        opts.on :c, :context, "Select object context to run under.", true do |context|
          target = Pry.binding_for(target.eval(context))
        end
        opts.on :h, :help, "This message." do
          output.puts opts
        end
      end

      next if opts.help?

      meth_name = args.shift
      if meth_name
        if meth_name =~ /\A([^\.\#]+)[\.\#](.+)\z/ && !opts.context?
          context, meth_name = $1, $2
          target = Pry.binding_for(target.eval(context))
        end
      else
        meth_name = meth_name_from_binding(target)
      end

      if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
        output.puts "Invalid method name: #{meth_name}."
        next
      end

      next output.puts "Error: No editor set!\nEnsure that #{bold("Pry.editor")} is set to your editor of choice." if !Pry.editor

      if is_a_c_method?(meth)
        output.puts "Error: Can't edit a C method."
      elsif is_a_dynamically_defined_method?(meth)
        output.puts "Error: Can't edit an eval method."

      # editor is invoked here
      else
        file, line = meth.source_location

        if Pry.editor.respond_to?(:call)
          editor_invocation = Pry.editor.call(file, line)
        else
          # only use start line if -n option is not used
          start_line_syntax = opts.n? ? "" : start_line_for_editor(line)
          editor_invocation = "#{Pry.editor} #{start_line_syntax} #{file}"
        end

        run ".#{editor_invocation}"
        load file if !opts["no-reload"]
      end
    end

    command "exit-program", "End the current program. Aliases: quit-program, !!!" do
      exit
    end

    alias_command "quit-program", "exit-program", ""
    alias_command "!!!", "exit-program", ""

    command "gem-install", "Install a gem and refresh the gem cache." do |gem_name|
      gem_home = Gem.instance_variable_get(:@gem_home)
      output.puts "Attempting to install gem: #{bold(gem_name)}"

      begin
        if File.writable?(gem_home)
          Gem::DependencyInstaller.new.install(gem_name)
          output.puts "Gem #{bold(gem_name)} successfully installed."
        else
          if system("sudo gem install #{gem_name}")
            output.puts "Gem #{bold(gem_name)} successfully installed."
          else
            output.puts "Gem #{bold(gem_name)} could not be installed."
            next
          end
        end
      rescue Gem::GemNotFoundException
        output.puts "Required Gem: #{bold(gem_name)} not found."
        next
      end

      Gem.refresh
      output.puts "Refreshed gem cache."
    end

    command "ri", "View ri documentation. e.g `ri Array#each`" do |*args|
      run ".ri", *args
    end

    command "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info." do |*args|
      target = target()

      opts = Slop.parse!(args) do |opts|
        opts.banner %{Usage: stat [OPTIONS] [METH]
Show method information for method METH and set _file_ and _dir_ locals.
e.g: stat hello_method
--
}
        opts.on :M, "instance-methods", "Operate on instance methods."
        opts.on :m, :methods, "Operate on methods."
        opts.on :c, :context, "Select object context to run under.", true do |context|
          target = Pry.binding_for(target.eval(context))
        end
        opts.on :h, :help, "This message" do
          output.puts opts
        end
      end

      next if opts.help?

      meth_name = args.shift
      if meth_name
        if meth_name =~ /\A([^\.\#]+)[\.\#](.+)\z/ && !opts.context?
          context, meth_name = $1, $2
          target = Pry.binding_for(target.eval(context))
        end
      else
        meth_name = meth_name_from_binding(target)
      end

      if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
        output.puts "Invalid method name: #{meth_name}. Type `stat --help` for help"
        next
      end

      code, code_type = code_and_code_type_for(meth)
      next if !code
      doc, code_type = doc_and_code_type_for(meth)

      output.puts make_header(meth, code_type, code)
      output.puts bold("Method Name: ") + meth_name
      output.puts bold("Method Owner: ") + (meth.owner.to_s ? meth.owner.to_s : "Unknown")
      output.puts bold("Method Language: ") + code_type.to_s.capitalize
      output.puts bold("Method Type: ") + (meth.is_a?(Method) ? "Bound" : "Unbound")
      output.puts bold("Method Arity: ") + meth.arity.to_s

      name_map = { :req => "Required:", :opt => "Optional:", :rest => "Rest:" }
      if meth.respond_to?(:parameters)
        output.puts bold("Method Parameters: ") + meth.parameters.group_by(&:first).
          map { |k, v| "#{name_map[k]} #{v.map { |kk, vv| vv ? vv.to_s : "noname" }.join(", ")}" }.join(". ")
      end
      output.puts bold("Comment length: ") + (doc.empty? ? 'No comment.' : (doc.lines.count.to_s + ' lines.'))
    end

    command "gist-method", "Gist a method to github. Type `gist-method --help` for more info.", :requires_gem => "gist" do |*args|
      target = target()

      opts = Slop.parse!(args) do |opts|
        opts.banner = %{Usage: gist-method [OPTIONS] [METH]
Gist the method (doc or source) to github.
Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
e.g: gist -m my_method
e.g: gist -d my_method
--
}
        opts.on :m, :method, "Gist a method's source."
        opts.on :d, :doc, "Gist a method's documentation."
        opts.on :p, :private, "Create a private gist (default: true)", :default => true
        opts.on :h, :help, "This message" do
          output.puts opts
        end
      end

      next if opts.help?

      # This needs to be extracted into its own method as it's shared
      # by show-method and show-doc and stat commands
      meth_name = args.shift
      if meth_name
        if meth_name =~ /\A([^\.\#]+)[\.\#](.+)\z/
          context, meth_name = $1, $2
          target = Pry.binding_for(target.eval(context))
        end
      else
        meth_name = meth_name_from_binding(target)
      end

      if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
        output.puts "Invalid method name: #{meth_name}. Type `gist-method --help` for help"
        next
      end

      type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
      if !opts.doc?
        content, code_type = code_and_code_type_for(meth)
      else
        content, code_type = doc_and_code_type_for(meth)
        no_color do
          content = process_comment_markup(content, code_type)
        end
        code_type = :plain
      end

      IO.popen("gist#{' -p' if opts.p?} -t #{type_map[code_type]} -", "w") do |gist|
        gist.puts content
      end
    end

    command "gem-cd", "Change working directory to specified gem's directory." do |gem_name|
      require 'rubygems'
      gem_spec = Gem.source_index.find_name(gem_name).first
      next output.puts("Gem `#{gem_name}` not found.") if !gem_spec
      Dir.chdir(File.expand_path(gem_spec.full_gem_path))
    end

    command "toggle-color", "Toggle syntax highlighting." do
      Pry.color = !Pry.color
      output.puts "Syntax highlighting #{Pry.color ? "on" : "off"}"
    end

    command "simple-prompt", "Toggle the simple prompt." do
      case Pry.active_instance.prompt
      when Pry::SIMPLE_PROMPT
        Pry.active_instance.prompt = Pry::DEFAULT_PROMPT
      else
        Pry.active_instance.prompt = Pry::SIMPLE_PROMPT
      end
    end

    command "shell-mode", "Toggle shell mode. Bring in pwd prompt and file completion." do
      case Pry.active_instance.prompt
      when Pry::SHELL_PROMPT
        Pry.active_instance.prompt = Pry::DEFAULT_PROMPT
        Pry.active_instance.custom_completions = Pry::DEFAULT_CUSTOM_COMPLETIONS
      else
        Pry.active_instance.prompt = Pry::SHELL_PROMPT
        Pry.active_instance.custom_completions = Pry::FILE_COMPLETIONS
        Readline.completion_proc = Pry::InputCompleter.build_completion_proc target,
        Pry.active_instance.instance_eval(&Pry::FILE_COMPLETIONS)
      end
    end

    alias_command "file-mode", "shell-mode", ""

    command "nesting", "Show nesting information." do
      nesting = opts[:nesting]

      output.puts "Nesting status:"
      output.puts "--"
      nesting.each do |level, obj|
        if level == 0
          output.puts "#{level}. #{Pry.view_clip(obj)} (Pry top level)"
        else
          output.puts "#{level}. #{Pry.view_clip(obj)}"
        end
      end
    end

    command "status", "Show status information." do
      nesting = opts[:nesting]

      output.puts "Status:"
      output.puts "--"
      output.puts "Receiver: #{Pry.view_clip(target.eval('self'))}"
      output.puts "Nesting level: #{nesting.level}"
      output.puts "Pry version: #{Pry::VERSION}"
      output.puts "Ruby version: #{RUBY_VERSION}"

      mn = meth_name_from_binding(target)
      output.puts "Current method: #{mn ? mn : "N/A"}"
      output.puts "Pry instance: #{Pry.active_instance}"
      output.puts "Last result: #{Pry.view(Pry.last_result)}"
    end


    command "req", "Requires gem(s). No need for quotes! (If the gem isn't installed, it will ask if you want to install it.)" do |*gems|
      gems = gems.join(' ').gsub(',', '').split(/\s+/)
      gems.each do |gem|
        begin
          if require gem
            output.puts "#{bright_yellow(gem)} loaded"
          else
            output.puts "#{bright_white(gem)} already loaded"
          end

        rescue LoadError => e

          if gem_installed? gem
            output.puts e.inspect
          else
            output.puts "#{bright_red(gem)} not found"
            if prompt("Install the gem?") == "y"
              run "gem-install", gem
            end
          end

        end # rescue
      end # gems.each
    end


    command "gem-list", "List/search installed gems. (Optional parameter: a regexp to limit the search)" do |arg|
      gems = Gem.source_index.gems.values.group_by(&:name)
      if arg
        query = Regexp.new(arg, Regexp::IGNORECASE)
        gems = gems.select { |gemname, specs| gemname =~ query }
      end

      gems.each do |gemname, specs|
        versions = specs.map(&:version).sort.reverse.map(&:to_s)
        versions = ["<bright_green>#{versions.first}</bright_green>"] +
                   versions[1..-1].map{|v| "<green>#{v}</green>" }

        gemname = highlight(gemname, query) if query
        result = "<white>#{gemname} <grey>(#{versions.join ', '})</grey>"
        output.puts colorize(result)
      end
    end


    command "whereami", "Show the code context for the session. (whereami <n> shows <n> extra lines of code around the invocation line. Default: 5)" do |num|
      file = target.eval('__FILE__')
      line_num = target.eval('__LINE__')
      klass = target.eval('self.class')

      if num
        i_num = num.to_i
      else
        i_num = 5
      end

      meth_name = meth_name_from_binding(target)
      meth_name = "N/A" if !meth_name

      if file =~ /(\(.*\))|<.*>/ || file == "" || file == "-e"
        output.puts "Cannot find local context. Did you use `binding.pry` ?"
        next
      end

      set_file_and_dir_locals(file)
      output.puts "\n#{bold('From:')} #{file} @ line #{line_num} in #{klass}##{meth_name}:\n\n"

      # This method inspired by http://rubygems.org/gems/ir_b
      File.open(file).each_with_index do |line, index|
        line_n = index + 1
        next unless line_n > (line_num - i_num - 1)
        break if line_n > (line_num + i_num)
        if line_n == line_num
          code =" =>#{line_n.to_s.rjust(3)}: #{line.chomp}"
          if Pry.color
            code = CodeRay.scan(code, :ruby).term
          end
          output.puts code
          code
        else
          code = "#{line_n.to_s.rjust(6)}: #{line.chomp}"
          if Pry.color
            code = CodeRay.scan(code, :ruby).term
          end
          output.puts code
          code
        end
      end
    end

    command "version", "Show Pry version." do
      output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
    end

    command "exit-all", "End all nested Pry sessions. Accepts optional return value. Aliases: !!@" do
      str = remove_first_word(opts[:val])
      throw(:breakout, [0, target.eval(str)])
    end

    alias_command "!!@", "exit-all", ""

    command "ls", "Show the list of vars and methods in the current scope. Type `ls --help` for more info." do |*args|
      options = {}
      # Set target local to the default -- note that we can set a different target for
      # ls if we like: e.g ls my_var
      target = target()

      OptionParser.new do |opts|
        opts.banner = %{Usage: ls [OPTIONS] [VAR]\n\
List information about VAR (the current context by default).
Shows local and instance variables by default.
--
}
        opts.on("-g", "--globals", "Display global variables.") do
          options[:g] = true
        end

        opts.on("-c", "--constants", "Display constants.") do
          options[:c] = true
        end

        opts.on("-l", "--locals", "Display locals.") do
          options[:l] = true
        end

        opts.on("-i", "--ivars", "Display instance variables.") do
          options[:i] = true
        end

        opts.on("-k", "--class-vars", "Display class variables.") do
          options[:k] = true
        end

        opts.on("-m", "--methods", "Display methods (public methods by default).") do
          options[:m] = true
        end

        opts.on("-M", "--instance-methods", "Display instance methods (only relevant to classes and modules).") do
          options[:M] = true
        end

        opts.on("-P", "--public", "Display public methods (with -m).") do
          options[:P] = true
        end

        opts.on("-r", "--protected", "Display protected methods (with -m).") do
          options[:r] = true
        end

        opts.on("-p", "--private", "Display private methods (with -m).") do
          options[:p] = true
        end

        opts.on("-j", "--just-singletons", "Display just the singleton methods (with -m).") do
          options[:j] = true
        end

        opts.on("-s", "--super", "Include superclass entries (relevant to constant and methods options).") do
          options[:s] = true
        end

        opts.on("-a", "--all", "Display all types of entries.") do
          options[:a] = true
        end

        opts.on("-v", "--verbose", "Verbose ouput.") do
          options[:v] = true
        end

        opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
          options[:f] = true
        end

        opts.on("--grep REG", "Regular expression to be used.") do |reg|
          options[:grep] = Regexp.new(reg)
        end

        opts.on_tail("-h", "--help", "Show this message.") do
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |new_target|
        target = Pry.binding_for(target.eval("#{new_target}")) if !options[:h]
      end

      # exit if we've displayed help
      next if options[:h]

      # default is locals/ivars/class vars.
      # Only occurs when no options or when only option is verbose
      options.merge!({
                       :l => true,
                       :i => true,
                       :k => true
                     }) if options.empty? || (options.size == 1 && options[:v]) || (options.size == 1 && options[:grep])

      options[:grep] = // if !options[:grep]


      # Display public methods by default if -m or -M switch is used.
      options[:P] = true if (options[:m] || options[:M]) && !(options[:p] || options[:r] || options[:j])

      info = {}
      target_self = target.eval('self')

      # ensure we have a real boolean and not a `nil` (important when
      # interpolating in the string)
      options[:s] = !!options[:s]

      # Numbers (e.g 0, 1, 2) are for ordering the hash values in Ruby 1.8
      i = -1

      # Start collecting the entries selected by the user
      info["local variables"] = [Array(target.eval("local_variables")).sort, i += 1] if options[:l] || options[:a]
      info["instance variables"] = [Array(target.eval("instance_variables")).sort, i += 1] if options[:i] || options[:a]

      info["class variables"] = [if target_self.is_a?(Module)
                                   Array(target.eval("class_variables")).sort
                                 else
                                   Array(target.eval("self.class.class_variables")).sort
                                 end, i += 1] if options[:k] || options[:a]

      info["global variables"] = [Array(target.eval("global_variables")).sort, i += 1] if options[:g] || options[:a]

      info["public methods"] = [Array(target.eval("public_methods(#{options[:s]})")).uniq.sort, i += 1] if (options[:m] && options[:P]) || options[:a]

      info["protected methods"] = [Array(target.eval("protected_methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:r]) || options[:a]

      info["private methods"] = [Array(target.eval("private_methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:p]) || options[:a]

      info["just singleton methods"] = [Array(target.eval("methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:j]) || options[:a]

      info["public instance methods"] = [Array(target.eval("public_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:P]) || options[:a])

      info["protected instance methods"] = [Array(target.eval("protected_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:r]) || options[:a])

      info["private instance methods"] = [Array(target.eval("private_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:p]) || options[:a])

      # dealing with 1.8/1.9 compatibility issues :/
      csuper = options[:s]
      if Module.method(:constants).arity == 0
        csuper = nil
      end

      info["constants"] = [Array(target_self.is_a?(Module) ? target.eval("constants(#{csuper})") :
                                 target.eval("self.class.constants(#{csuper})")).uniq.sort, i += 1] if options[:c] || options[:a]

      text = ""

      # verbose output?
      if options[:v]
        # verbose

        info.sort_by { |k, v| v.last }.each do |k, v|
          if !v.first.empty?
            text <<  "#{k}:\n--\n"
            filtered_list = v.first.grep options[:grep]
            if Pry.color
              text << CodeRay.scan(Pry.view(filtered_list), :ruby).term + "\n"
            else
              text << Pry.view(filtered_list) + "\n"
            end
            text << "\n\n"
          end
        end

        if !options[:f]
          stagger_output(text)
        else
          output.puts text
        end

      # plain
      else
        list = info.values.sort_by(&:last).map(&:first).inject(&:+)
        list = list.grep(options[:grep]) if list
        list.uniq! if list
        if Pry.color
          text << CodeRay.scan(Pry.view(list), :ruby).term + "\n"
        else
          text <<  Pry.view(list) + "\n"
        end
        if !options[:f]
          stagger_output(text)
        else
          output.puts text
        end
        list
      end
    end

    command "lls", "List local files using 'ls'" do |*args|
      cmd = ".ls"
      run cmd, *args
    end

    command "lcd", "Change the current (working) directory" do |*args|
      run ".cd", *args
    end

    command "cat", "Show output of file FILE. Type `cat --help` for more information." do |*args|
      options= {}
      file_name = nil
      start_line = 0
      end_line = -1
      file_type = nil

      OptionParser.new do |opts|
        opts.banner = %{Usage: cat [OPTIONS] FILE
Cat a file. Defaults to displaying whole file. Syntax highlights file if type is recognized.
e.g: cat hello.rb
--
}
        opts.on("-l", "--line-numbers", "Show line numbers.") do |line|
          options[:l] = true
        end

        opts.on("-s", "--start LINE", "Start line (defaults to start of file). Line 1 is the first line.") do |line|
          start_line = line.to_i - 1
        end

        opts.on("-e", "--end LINE", "End line (defaults to end of file). Line -1 is the last line.") do |line|
          end_line = line.to_i - 1
        end

        opts.on("-t", "--type TYPE", "The specific file type for syntax higlighting (e.g ruby, python, cpp, java)") do |type|
          file_type = type.to_sym
        end

        opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
          options[:f] = true
        end

        opts.on_tail("-h", "--help", "This message.") do
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        file_name = v
      end

      next if options[:h]

      if !file_name
        output.puts "Must provide a file name."
        next
      end

      contents, normalized_start_line, _ = read_between_the_lines(file_name, start_line, end_line)

      if Pry.color
        contents = syntax_highlight_by_file_type_or_specified(contents, file_name, file_type)
      end

      set_file_and_dir_locals(file_name)
      render_output(options[:f], options[:l] ? normalized_start_line + 1 : false, contents)
      contents
    end

    command "eval-file", "Eval a Ruby script. Type `eval-file --help` for more info." do |*args|
      options = {}
      target = target()
      file_name = nil

      OptionParser.new do |opts|
        opts.banner = %{Usage: eval-file [OPTIONS] FILE
Eval a Ruby script at top-level or in the specified context. Defaults to top-level.
e.g: eval-file -c self "hello.rb"
--
}
        opts.on("-c", "--context CONTEXT", "Eval the script in the specified context.") do |context|
          options[:c] = true
          target = Pry.binding_for(target.eval(context))
        end

        opts.on_tail("-h", "--help", "This message.") do
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        file_name = v
      end

      next if options[:h]

      if !file_name
        output.puts "You need to specify a file name. Type `eval-file --help` for help"
        next
      end

      old_constants = Object.constants
      if options[:c]
        target_self = target.eval('self')
        target.eval(File.read(File.expand_path(file_name)))
        output.puts "--\nEval'd '#{file_name}' in the `#{target_self}`  context."
      else
        TOPLEVEL_BINDING.eval(File.read(File.expand_path(file_name)))
        output.puts "--\nEval'd '#{file_name}' at top-level."
      end
      set_file_and_dir_locals(file_name)

      new_constants = Object.constants - old_constants
      output.puts "Brought in the following top-level constants: #{new_constants.inspect}" if !new_constants.empty?
    end

    command "cd", "Start a Pry session on VAR (use `cd ..` to go back and `cd /` to return to Pry top-level)",  :keep_retval => true do |obj|
      if !obj
        output.puts "Must provide an object."
        next
      end

      throw(:breakout, opts[:nesting].level) if obj == ".."

      if obj == "/"
        throw(:breakout, 1) if opts[:nesting].level > 0
        next
      end

      Pry.start target.eval("#{obj}")
    end

    command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?" do |*args|
      target = target()

      opts = Slop.parse!(args) do |opts|
        opts.banner %{Usage: show-doc [OPTIONS] [METH]
Show the comments above method METH. Tries instance methods first and then methods by default.
e.g show-doc hello_method
--
}
        opts.on :M, "instance-methods", "Operate on instance methods."
        opts.on :m, :methods, "Operate on methods."
        opts.on :c, :context, "Select object context to run under.", true do |context|
          target = Pry.binding_for(target.eval(context))
        end
        opts.on :f, :flood, "Do not use a pager to view text longer than one screen."
        opts.on :h, :help, "This message." do
          output.puts opts
        end
      end

      next if opts.help?

      meth_name = args.shift
      if meth_name
        if meth_name =~ /\A([^\.\#]+)[\.\#](.+)\z/ && !opts.context?
          context, meth_name = $1, $2
          target = Pry.binding_for(target.eval(context))
        end
      else
        meth_name = meth_name_from_binding(target)
      end

      if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
        output.puts "Invalid method name: #{meth_name}. Type `show-doc --help` for help"
        next
      end

      doc, code_type = doc_and_code_type_for(meth)
      next if !doc

      next output.puts("No documentation found.") if doc.empty?

      doc = process_comment_markup(doc, code_type)

      output.puts make_header(meth, code_type, doc)

      render_output(opts.flood?, false, doc)
      doc
    end

    alias_command "?", "show-doc", ""

    command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: $, show-source" do |*args|
      target = target()

      opts = Slop.parse!(args) do |opts|
        opts.banner %{Usage: show-method [OPTIONS] [METH]
Show the source for method METH. Tries instance methods first and then methods by default.
e.g: show-method hello_method
--
}
        opts.on :l, "line-numbers", "Show line numbers."
        opts.on :M, "instance-methods", "Operate on instance methods."
        opts.on :m, :methods, "Operate on methods."
        opts.on :f, :flood, "Do not use a pager to view text longer than one screen."
        opts.on :c, :context, "Select object context to run under.", true do |context|
          target = Pry.binding_for(target.eval(context))
        end
        opts.on :h, :help, "This message." do
          output.puts opts
        end
      end

      next if opts.help?

      meth_name = args.shift
      if meth_name
        if meth_name =~ /\A([^\.\#]+)[\.\#](.+)\z/ && !opts.context?
          context, meth_name = $1, $2
          target = Pry.binding_for(target.eval(context))
        end
      else
        meth_name = meth_name_from_binding(target)
      end

      if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
        output.puts "Invalid method name: #{meth_name}. Type `show-method --help` for help"
        next
      end

      code, code_type = code_and_code_type_for(meth)
      next if !code

      output.puts make_header(meth, code_type, code)
      if Pry.color
        code = CodeRay.scan(code, code_type).term
      end

      start_line = false
      if opts.l?
        start_line = meth.source_location ? meth.source_location.last : 1
      end

      render_output(opts.flood?, start_line, code)
      code
    end

    alias_command "show-source", "show-method", ""
    alias_command "$", "show-method", ""

    command "show-command", "Show the source for CMD. Type `show-command --help` for more info." do |*args|
      options = {}
      target = target()
      command_name = nil

      OptionParser.new do |opts|
        opts.banner = %{Usage: show-command [OPTIONS] [CMD]
Show the source for command CMD.
e.g: show-command show-method
--
}
        opts.on("-l", "--line-numbers", "Show line numbers.") do |line|
          options[:l] = true
        end

        opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
          options[:f] = true
        end

        opts.on_tail("-h", "--help", "This message.") do
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        command_name = v
      end

      next if options[:h]

      if !command_name
        output.puts "You must provide a command name."
        next
      end

      if commands[command_name]
        meth = commands[command_name].block

        code = strip_leading_whitespace(meth.source)
        file, line = meth.source_location
        set_file_and_dir_locals(file)
        check_for_dynamically_defined_method(meth)

        output.puts make_header(meth, :ruby, code)

        if Pry.color
          code = CodeRay.scan(code, :ruby).term
        end

        render_output(options[:f], options[:l] ? meth.source_location.last : false, code)
        code
      else
        output.puts "No such command: #{command_name}."
      end
    end

    command "jump-to", "Jump to a Pry session further up the stack, exiting all sessions below." do |break_level|
      break_level = break_level.to_i
      nesting = opts[:nesting]

      case break_level
      when nesting.level
        output.puts "Already at nesting level #{nesting.level}"
      when (0...nesting.level)
        throw(:breakout, break_level + 1)
      else
        max_nest_level = nesting.level - 1
        output.puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
      end
    end

    command "exit", "End the current Pry session. Accepts optional return value. Aliases: quit, back" do
      str = remove_first_word(opts[:val])
      throw(:breakout, [opts[:nesting].level, target.eval(str)])
    end

    alias_command "quit", "exit", ""
    alias_command "back", "exit", ""

    command "game", "" do |highest|
      highest = highest ? highest.to_i : 100
      num = rand(highest)
      output.puts "Guess the number between 0-#{highest}: ('.' to quit)"
      count = 0
      while(true)
        count += 1
        str = Readline.readline("game > ", true)
        break if str == "." || !str
        val = str.to_i
        output.puts "Too large!" if val > num
        output.puts "Too small!" if val < num
        if val == num
          output.puts "Well done! You guessed right! It took you #{count} guesses."
          break
        end
      end
    end

    command "east-coker", "" do
      text = %{
--
Now the light falls
Across the open field, leaving the deep lane
Shuttered with branches, dark in the afternoon,
Where you lean against a bank while a van passes,
And the deep lane insists on the direction
Into the village, in the electric heat
Hypnotised. In a warm haze the sultry light
Is absorbed, not refracted, by grey stone.
The dahlias sleep in the empty silence.
Wait for the early owl.
-- T.S Eliot
            }
      output.puts text
      text
    end

    command "cohen-poem", "" do
      text = %{
--
When this American woman,
whose thighs are bound in casual red cloth,
comes thundering past my sitting place
like a forest-burning Mongol tribe,
the city is ravished
and brittle buildings of a hundred years
splash into the street;
and my eyes are burnt
for the embroidered Chinese girls,
already old,
and so small between the thin pines
on these enormous landscapes,
that if you turn your head
they are lost for hours.
-- Leonard Cohen
                }
  output.puts text
  text
end
end
end
