direc = File.dirname(__FILE__)
require "#{direc}/command_base"
require "optparse"

class Pry

  # Default commands used by Pry.
  class Commands < CommandBase

    # We make this a lambda to avoid documenting it
    meth_name_from_binding = lambda do |b|
      meth_name = b.eval('__method__')
      if [nil, :__binding__, :__binding_impl__].include?(meth_name)
        nil
      else
        meth_name
      end
    end
    
    command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop." do
      output.puts "Input buffer cleared!"
      opts[:eval_string].clear
    end

    command "!pry", "Start a Pry session on current self; this even works mid-expression." do
      Pry.start(target)
    end

    command "exit-program", "End the current program. Aliases: quit-program" do
      exit
    end

    alias_command "quit-program", "exit-program", ""

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
      output.puts "Pry version: #{Pry::VERSION}"
    end
    
    command "exit-all", "End all nested Pry sessions." do
      throw(:breakout, 0) 
    end

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

        opts.on("-m", "--methods", "Display methods.") do 
          options[:m] = true
        end

        opts.on("-M", "--instance-methods", "Display instance methods (only relevant to classes and modules).") do
          options[:M] = true
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
      
      info["methods"] = [Array(target.eval("methods(#{options[:s]}) + public_methods(#{options[:s]}) +\
        protected_methods(#{options[:s]}) +\
        private_methods(#{options[:s]})")).uniq.sort, i += 1] if options[:m] || options[:a]

      info["instance methods"] = [Array(target.eval("instance_methods(#{options[:s]}) +\
        public_instance_methods(#{options[:s]}) +\
        protected_instance_methods(#{options[:s]}) +\
        private_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && (options[:M] || options[:a])
      
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
        info.each.sort_by { |k, v| v.last }.each do |k, v|
          if !v.first.empty?
            output.puts "#{k}:\n--"
            output.puts Pry.view(v.first)
            output.puts
          end
        end

      # plain
      else
        output.puts Pry.view(info.values.sort_by { |v| v.last }.map { |v| v.first }.inject(&:+))
      end
    end

    command "cat-file", "Show output of file FILE" do |file_name|
      if !file_name
        output.puts "Must provide a file name."
        next
      end

      output.puts File.read(file_name)
    end

    command "eval-file", "Eval a Ruby script. Type `eval-file --help` for more info." do |*args|
      options = {}
      file_name = nil
      
      OptionParser.new do |opts|
        opts.banner = %{Usage: eval-file [OPTIONS] FILE
Eval a Ruby script at top-level or in the current context.
e.g: eval-script -c "hello.rb"
--
}
        opts.on("-c", "--context", "Eval the script in the current context.") do 
          options[:c] = true
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
        output.puts "You need to specify a file name. Type `eval-script --help` for help"
        next
      end

      old_constants = Object.constants
      if options[:c]
        target.eval(File.read(file_name))
        output.puts "--\nEval'd '#{file_name}' in the current context."
      else
        TOPLEVEL_BINDING.eval(File.read(file_name))
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
    
    command "cd", "Start a Pry session on VAR (use `cd ..` to go back)" do |obj|
      if !obj
        output.puts "Must provide an object."
        next
      end
      
      throw(:breakout, opts[:nesting].level) if obj == ".."
      target.eval("#{obj}.pry")
    end

    command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info." do |*args|
      options = {}
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
      output.puts "From #{file} @ line ~#{line}:\n--"
      output.puts doc
    end

    command "show-method", "Show the source for METH. Type `show-method --help` for more info." do |*args|
      options = {}
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
        output.puts "Invalid method name: #{meth_name}. Type `show-method --help` for help"
        next
      end

      code = meth.source
      file, line = meth.source_location
      output.puts "From #{file} @ line #{line}:\n--"
      output.puts code
    end
    
    command "show-command", "Show sourcecode for a Pry command, e.g: show-command ls" do |command_name|
      cmds = Pry.active_instance.commands.commands
      
      if !command_name
        output.puts "You must provide a command name."
        next
      end
      
      if cmds[command_name]
        meth = cmds[command_name][:action]
        code = meth.source
        file, line = meth.source_location
        output.puts "From #{file} @ line #{line}:\n--"
        output.puts code
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

    command "exit", "End the current Pry session. Aliases: quit, back" do
      throw(:breakout, opts[:nesting].level)
    end

    alias_command "quit", "exit", ""
    alias_command "back", "exit", ""
  end
end
