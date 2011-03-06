require "optparse"
require "method_source"
require "pry/command_base"
require "pry/pry_instance"

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

    check_for_dynamically_defined_method = lambda do |file|
      if file =~ /(\(.*\))|<.*>/
        raise "Cannot retrieve source for dynamically defined method."
      end
    end

    remove_first_word = lambda do |text|
      text.split.drop(1).join(' ')
    end

    command "whereami", "Show the code context for the session." do
      file = target.eval('__FILE__')
      line_num = target.eval('__LINE__')
      klass = target.eval('self.class')

      meth_name = meth_name_from_binding.call(target)
      if !meth_name
        output.puts "Cannot find containing method. Did you remember to use \`binding.pry\` ?"
        next
      end

      check_for_dynamically_defined_method.call(file)
     
      output.puts "--\nFrom #{file} @ line #{line_num} in #{klass}##{meth_name}:\n--"
      
      # This method inspired by http://rubygems.org/gems/ir_b
      File.open(file).each_with_index do |line, index|
        line_n = index + 1
        next unless line_n > (line_num - 6)
        break if line_n > (line_num + 5)
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
      options[:P] = true if (options[:m] || options[:M]) && !(options[:p] || options[:r])
      
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
        list = info.values.sort_by { |v| v.last }.map { |v| v.first }.inject(&:+)
        if Pry.color
          output.puts CodeRay.scan(Pry.view(list), :ruby).term
        else
          output.puts Pry.view(list)
        end
        list
      end
    end

    command "cat-file", "Show output of file FILE" do |file_name|
      if !file_name
        output.puts "Must provide a file name."
        next
      end

      contents = File.read(File.expand_path(file_name))
      output.puts contents
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

      target.eval("#{obj}.pry")
    end

    command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info." do |*args|
      options = {}
      target = target()
      meth_name = nil
      
      OptionParser.new do |opts|
        opts.banner = %{Usage: show-doc [OPTIONS] [METH]
Show the comments above method METH. Shows _method_ comments (rather than instance methods) by default.
e.g show-doc hello_method
--
}
        opts.on("-M", "--instance-methods", "Operate on instance methods instead.") do 
          options[:M] = true
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

      if !meth_name
        output.puts "You need to specify a method. Type `show-doc --help` for help"
        next
      end
      
      begin
        if options[:M]
          meth = target.eval("instance_method(:#{meth_name})")
        else
          meth = target.eval("method(:#{meth_name})")
        end
      rescue
        output.puts "Invalid method name: #{meth_name}. Type `show-doc --help` for help"
        next
      end

      doc = meth.comment
      file, line = meth.source_location
      check_for_dynamically_defined_method.call(file)

      output.puts "--\nFrom #{file} @ line ~#{line}:\n--"

      if Pry.color
        doc = CodeRay.scan(doc, :ruby).term
      end

      output.puts doc
      doc
    end

    command "show-method", "Show the source for METH. Type `show-method --help` for more info." do |*args|
      options = {}
      target = target()
      meth_name = nil
      
      OptionParser.new do |opts|
        opts.banner = %{Usage: show-method [OPTIONS] [METH]
Show the source for method METH. Shows _method_ source (rather than instance methods) by default.
e.g: show-method hello_method
--
}
        opts.on("-M", "--instance-methods", "Operate on instance methods instead.") do 
          options[:M] = true
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

      # If no method name is given then use current method, if it exists
      meth_name = meth_name_from_binding.call(target) if !meth_name

      if !meth_name
        output.puts "You need to specify a method. Type `show-method --help` for help"
        next
      end
      
      begin
        if options[:M]
          meth = target.eval("instance_method(:#{meth_name})")
        else
          meth = target.eval("method(:#{meth_name})")
        end
      rescue
        target_self = target.eval('self')
        if !options[:M]&& target_self.is_a?(Module) &&
            target_self.method_defined?(meth_name)
          output.puts "Did you mean: show-method -M #{meth_name} ?"
        end
        output.puts "Invalid method name: #{meth_name}. Type `show-method --help` for help"
        next
      end

      code = meth.source
      file, line = meth.source_location
      check_for_dynamically_defined_method.call(file)
      
      output.puts "--\nFrom #{file} @ line #{line}:\n--"

      if Pry.color
        code = CodeRay.scan(code, :ruby).term
      end
      
      output.puts code
      code
    end
    
    command "show-command", "Show sourcecode for a Pry command, e.g: show-command cd" do |command_name|
      if !command_name
        output.puts "You must provide a command name."
        next
      end
      
      if commands[command_name]
        meth = commands[command_name][:action]

        code = meth.source
        file, line = meth.source_location
        check_for_dynamically_defined_method.call(file)

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
