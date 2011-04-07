direc = File.dirname(__FILE__)

require "optparse"
require "method_source"
require "#{direc}/command_base"
require "#{direc}/pry_instance"

begin

  # YARD crashes on rbx, so do not require it 
  if !Object.const_defined?(:RUBY_ENGINE) || RUBY_ENGINE !~ /rbx/
    require "pry-doc"
  end
rescue LoadError
end

class Pry

  # Default commands used by Pry.
  class Commands < CommandBase

    # We make this a lambda to avoid documenting it
    meth_name_from_binding = lambda do |b|
      meth_name = b.eval('__method__')

      # :__script__ for rubinius
      if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
        nil
      else
        meth_name
      end
    end

    check_for_dynamically_defined_method = lambda do |meth|
      file, _ = meth.source_location
      if file =~ /(\(.*\))|<.*>/
        raise "Cannot retrieve source for dynamically defined method."
      end
    end

    remove_first_word = lambda do |text|
      text.split.drop(1).join(' ')
    end

    get_method_object = lambda do |meth_name, target, options|
      if !meth_name
        return nil
      end

      if options[:M]
        target.eval("instance_method(:#{meth_name})")
      elsif options[:m]
        target.eval("method(:#{meth_name})")
      else
        begin
          target.eval("instance_method(:#{meth_name})")
        rescue
          begin
            target.eval("method(:#{meth_name})")
          rescue
            return nil
          end
        end
      end
    end

    make_header = lambda do |meth, code_type|
      file, line = meth.source_location
      header = case code_type
               when :ruby
                 "--\nFrom #{file} @ line #{line}:\n--"
               else
                 "--\nFrom Ruby Core (C Method):\n--"
               end
    end

    is_a_c_method = lambda do |meth|
      meth.source_location.nil?
    end

    should_use_pry_doc = lambda do |meth|
      Pry.has_pry_doc && is_a_c_method.call(meth)
    end
    
    code_type_for = lambda do |meth|
      # only C methods
      if should_use_pry_doc.call(meth)
        info = Pry::MethodInfo.info_for(meth) 
        if info && info.source
          code_type = :c
        else
          output.puts "Cannot find C method: #{meth.name}"
          code_type = nil
        end
      else
        if is_a_c_method.call(meth)
          output.puts "Cannot locate this method: #{meth.name}. Try `gem install pry-doc` to get access to Ruby Core documentation."
          code_type = nil
        else
          check_for_dynamically_defined_method.call(meth)
          code_type = :ruby
        end
      end
      code_type
    end

    command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
      output.puts "Input buffer cleared!"
      opts[:eval_string].clear
    end

    command "!pry", "Start a Pry session on current self; this even works mid-expression." do
      Pry.start(target)
    end

    command "exit-program", "End the current program. Aliases: quit-program, !!!" do
      exit
    end

    alias_command "quit-program", "exit-program", ""
    alias_command "!!!", "exit-program", ""

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

    # FIXME: when restoring backups does not restore descriptions
    command "file-mode", "Toggle file mode." do
      case Pry.active_instance.prompt
      when Pry::FILE_PROMPT
        Pry.active_instance.prompt = Pry::DEFAULT_PROMPT
        Pry.active_instance.custom_completions = Pry::DEFAULT_CUSTOM_COMPLETIONS
      else
        Pry.active_instance.prompt = Pry::FILE_PROMPT
        Pry.active_instance.custom_completions = Pry::FILE_COMPLETIONS
      end        
    end

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

      mn = meth_name_from_binding.call(target)
      output.puts "Current method: #{mn ? mn : "N/A"}"
      output.puts "Pry instance: #{Pry.active_instance}"
      output.puts "Last result: #{Pry.view(Pry.last_result)}"
    end

    command "whereami", "Show the code context for the session. Shows AROUND lines around the invocation line. AROUND defaults to 5 lines. " do |num|
      file = target.eval('__FILE__')
      line_num = target.eval('__LINE__')
      klass = target.eval('self.class')

      if num
        i_num = num.to_i
      else
        i_num = 5
      end
      
      meth_name = meth_name_from_binding.call(target)
      meth_name = "N/A" if !meth_name

      if file =~ /(\(.*\))|<.*>/ || file == ""
        output.puts "Cannot find local context. Did you use `binding.pry` ?"
        next
      end
     
      output.puts "--\nFrom #{file} @ line #{line_num} in #{klass}##{meth_name}:\n--"
      
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
    
    command "exit-all", "End all nested Pry sessions. Accepts optional return value. Aliases: !@" do 
      str = remove_first_word.call(opts[:val])
      throw(:breakout, [0, target.eval(str)])
    end

    alias_command "!@", "exit-all", ""

    command "ls", "Show the list of vars in the current scope. Type `ls --help` for more info." do |*args|
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
                     }) if options.empty? || (options.size == 1 && options[:v])

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

      # verbose output?
      if options[:v]

        # verbose
        info.sort_by { |k, v| v.last }.each do |k, v|
          if !v.first.empty?
            output.puts "#{k}:\n--"
            if Pry.color
              output.puts CodeRay.scan(Pry.view(v.first), :ruby).term
            else
              output.puts Pry.view(v.first)
            end
            output.puts
          end
        end

      # plain
      else
        list = info.values.sort_by(&:last).map(&:first).inject(&:+)
        list.uniq! if list
        if Pry.color
          output.puts CodeRay.scan(Pry.view(list), :ruby).term
        else
          output.puts Pry.view(list)
        end
        list
      end
    end

    file_map = {
      [".c", ".h"] => :c,
      [".cpp", ".hpp", ".cc", ".h", "cxx"] => :cpp,
      ".rb" => :ruby,
      ".py" => :python,
      ".diff" => :diff,
      ".css" => :css,
      ".html" => :html,
      [".yaml", ".yml"] => :yaml,
      ".xml" => :xml,
      ".php" => :php,
      ".js" => :javascript,
      ".java" => :java,
      ".rhtml" => :rhtml,
      ".json" => :json
    }

    syntax_highlight_by_file_type = lambda do |contents, file_name|
      _, language_detected = file_map.find { |k, v| Array(k).include?(File.extname(file_name)) }

      CodeRay.scan(contents, language_detected).term
    end

    read_between_the_lines = lambda do |file_name, start_line, end_line, with_line_numbers|
      content = File.read(File.expand_path(file_name))

      if with_line_numbers
        lines = content.each_line.map.with_index { |line, idx| "#{idx + 1}: #{line}" }
      else
        lines = content.each_line.to_a
      end
      
      lines[start_line..end_line].join
    end

    add_line_numbers = lambda do |lines, start_line|
      lines.each_line.map.with_index do |line, idx|
        adjusted_index = idx + start_line
        if Pry.color
          cindex = CodeRay.scan("#{adjusted_index}", :ruby).term
          "#{cindex}: #{line}"
        else
          "#{idx}: #{line}"
        end
      end
    end
    
    command "cat-file", "Show output of file FILE. Type `cat --help` for more information. Aliases: :cat" do |*args|
      options= {}
      file_name = nil
      start_line = 0
      end_line = -1

      OptionParser.new do |opts|
        opts.banner = %{Usage: cat-file [OPTIONS] FILE
Cat a file. Defaults to displaying whole file. Syntax highlights file if type is recognized.
e.g: cat-file hello.rb
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

      contents = read_between_the_lines.call(file_name, start_line, end_line, false)

      if Pry.color
        contents = syntax_highlight_by_file_type.call(contents, file_name)
      end

      if options[:l]
        contents = add_line_numbers.call(contents, start_line + 1)
      end
      
      output.puts contents
      contents
    end

    alias_command ":cat", "cat-file", ""

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
      new_constants = Object.constants - old_constants
      output.puts "Brought in the following top-level constants: #{new_constants.inspect}" if !new_constants.empty?
    end      

    command "cat", "Show output of VAR.inspect. Aliases: inspect" do |obj|
      if !obj
        output.puts "Must provide an object to inspect."
        next
      end
      
      output.puts Pry.view(target.eval("#{obj}"))
    end

    alias_command "inspect", "cat", ""
    
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

    strip_color_codes = lambda do |str|
      str.gsub(/\e\[.*?(\d)+m/, '')
    end

    process_rdoc = lambda do |comment, code_type|
      comment = comment.dup
      comment.gsub(/<code>(?:\s*\n)?(.*?)\s*<\/code>/m) { Pry.color ? CodeRay.scan($1, code_type).term : $1 }.
        gsub(/<em>(?:\s*\n)?(.*?)\s*<\/em>/m) { Pry.color ? "\e[32m#{$1}\e[0m": $1 }.
        gsub(/<i>(?:\s*\n)?(.*?)\s*<\/i>/m) { Pry.color ? "\e[34m#{$1}\e[0m" : $1 }.
        gsub(/\B\+(\w*?)\+\B/)  { Pry.color ? "\e[32m#{$1}\e[0m": $1 }.
        gsub(/((?:^[ \t]+.+(?:\n+|\Z))+)/)  { Pry.color ? CodeRay.scan($1, code_type).term : $1 }.
        gsub(/`(?:\s*\n)?(.*?)\s*`/) { Pry.color ? CodeRay.scan($1, code_type).term : $1 }
    end

    process_yardoc_tag = lambda do |comment, tag|
      in_tag_block = nil
      output = comment.lines.map do |v|
        if in_tag_block && v !~ /^\S/
          strip_color_codes.call(strip_color_codes.call(v))
        elsif in_tag_block
          in_tag_block = false
          v
        else
          in_tag_block = true if v =~ /^@#{tag}/
          v
        end
      end.join
    end
      
    # FIXME - invert it -- should only ALLOW color if @example
    process_yardoc = lambda do |comment|
      yard_tags = ["param", "return", "option", "yield", "attr", "attr_reader", "attr_writer",
                   "deprecate", "example"]
      (yard_tags - ["example"]).inject(comment) { |a, v| process_yardoc_tag.call(a, v) }.
        gsub(/^@(#{yard_tags.join("|")})/) { Pry.color ? "\e[33m#{$1}\e[0m": $1 }
    end
    
    process_comment_markup = lambda do |comment, code_type|
      process_yardoc.call process_rdoc.call(comment, code_type)
    end

    # strip leading whitespace but preserve indentation
    strip_leading_whitespace = lambda do |text|
      return text if text.empty?
      leading_spaces = text.lines.first[/^(\s+)/, 1]
      text.gsub(/^#{leading_spaces}/, '')
    end

    strip_leading_hash_and_whitespace_from_ruby_comments = lambda do |comment|
      comment = comment.dup
      comment.gsub!(/\A\#+?$/, '')
      comment.gsub!(/^\s*#/, '')
      strip_leading_whitespace.call(comment)
    end

    command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?" do |*args|
      options = {}
      target = target()
      meth_name = nil
      
      OptionParser.new do |opts|
        opts.banner = %{Usage: show-doc [OPTIONS] [METH]
Show the comments above method METH. Tries instance methods first and then methods by default.
e.g show-doc hello_method
--
}
        opts.on("-M", "--instance-methods", "Operate on instance methods.") do 
          options[:M] = true
        end

        opts.on("-m", "--methods", "Operate on methods.") do 
          options[:m] = true
        end

        opts.on("-c", "--context CONTEXT", "Select object context to run under.") do |context|
          target = Pry.binding_for(target.eval(context))
        end

        opts.on_tail("-h", "--help", "This message.") do 
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        meth_name = v
      end

      next if options[:h]

      if (meth = get_method_object.call(meth_name, target, options)).nil?
        output.puts "Invalid method name: #{meth_name}. Type `show-doc --help` for help"
        next
      end

      case code_type = code_type_for.call(meth)
      when nil
        next
      when :c
        doc = Pry::MethodInfo.info_for(meth).docstring
      when :ruby
        doc = meth.comment
        doc = strip_leading_hash_and_whitespace_from_ruby_comments.call(doc)
      end

      next output.puts("No documentation found.") if doc.empty?
      
      doc = process_comment_markup.call(doc, code_type)
      
      output.puts make_header.call(meth, code_type)
      output.puts doc
      doc
    end

    alias_command "?", "show-doc", ""

    strip_comments_from_c_code = lambda do |code|
      code.sub /\A\s*\/\*.*?\*\/\s*/m, ''
    end
    
    command "show-method", "Show the source for METH. Type `show-method --help` for more info. Aliases: show-source" do |*args|
      options = {}
      target = target()
      meth_name = nil
      
      OptionParser.new do |opts|
        opts.banner = %{Usage: show-method [OPTIONS] [METH]
Show the source for method METH. Tries instance methods first and then methods by default.
e.g: show-method hello_method
--
}
        opts.on("-l", "--line-numbers", "Show line numbers.") do |line|
          options[:l] = true
        end

        opts.on("-M", "--instance-methods", "Operate on instance methods.") do 
          options[:M] = true
        end

        opts.on("-m", "--methods", "Operate on methods.") do 
          options[:m] = true
        end

        opts.on("-c", "--context CONTEXT", "Select object context to run under.") do |context|
          target = Pry.binding_for(target.eval(context))
        end

        opts.on_tail("-h", "--help", "This message.") do 
          output.puts opts
          options[:h] = true
        end
      end.order(args) do |v|
        meth_name = v
      end

      next if options[:h]

      meth_name = meth_name_from_binding.call(target) if !meth_name

      if (meth = get_method_object.call(meth_name, target, options)).nil?
        output.puts "Invalid method name: #{meth_name}. Type `show-method --help` for help"
        next
      end
    
      case code_type = code_type_for.call(meth)
      when nil
        next
      when :c
        code = Pry::MethodInfo.info_for(meth).source
        code = strip_comments_from_c_code.call(code)
      when :ruby
        code = strip_leading_whitespace.call(meth.source)
      end

      output.puts make_header.call(meth, code_type)
      if Pry.color
        code = CodeRay.scan(code, code_type).term
      end

      if options[:l]
        start_line = meth.source_location ? meth.source_location.last : 1
        code = add_line_numbers.call(code, start_line)
      end
      
      output.puts code
      code
    end

    alias_command "show-source", "show-method", ""
    
    command "show-command", "Show sourcecode for a Pry command, e.g: show-command cd" do |command_name|
      if !command_name
        output.puts "You must provide a command name."
        next
      end
      
      if commands[command_name]
        meth = commands[command_name][:action]

        code = strip_leading_whitespace.call(meth.source)
        file, line = meth.source_location
        check_for_dynamically_defined_method.call(meth)

        output.puts "--\nFrom #{file} @ line #{line}:\n--"

        if Pry.color
          code = CodeRay.scan(code, :ruby).term
        end

        output.puts code
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
      str = remove_first_word.call(opts[:val])
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
