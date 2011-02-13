direc = File.dirname(__FILE__)
require "#{direc}/command_base"

class Pry

  # Default commands used by Pry.
  class Commands < CommandBase
    
    command "!", "Clear the input buffer. Useful if the parsing process goes wrong." do
      output.puts "Input buffer cleared!"
      opts[:eval_string].clear
    end

    command "!pry", "Start a Pry session on current self; this even works mid-expression." do
      Pry.start(target)
    end

    command ["exit_program", "quit_program"], "End the current program." do
      exit
    end

    command "nesting", "Show nesting information." do 
      out = output
      nesting = opts[:nesting]
      
      out.puts "Nesting status:"
      out.puts "--"
      nesting.each do |level, obj|
        if level == 0
          out.puts "#{level}. #{Pry.view_clip(obj)} (Pry top level)"
        else
          out.puts "#{level}. #{Pry.view_clip(obj)}"
        end
      end
    end

    command "status", "Show status information." do
      out = output
      nesting = opts[:nesting]
      
      out.puts "Status:"
      out.puts "--"
      out.puts "Receiver: #{Pry.view_clip(target.eval('self'))}"
      out.puts "Nesting level: #{nesting.level}"
      out.puts "Local variables: #{Pry.view(target.eval('local_variables'))}"
      out.puts "Pry instance: #{Pry.active_instance}"
      out.puts "Last result: #{Pry.view(Pry.last_result)}"
    end

    command "exit_all", "End all nested Pry sessions." do
      throw(:breakout, 0) 
    end

    command "ls", "Show the list of vars in the current scope. Use -c to include constants and -g to include globals." do |*args|
      params = []
      args.each do |v|
        if v[0].chr == "-"
          params += v[1..-1].split("")
        end
      end

      target_self = target.eval('self')

      extras = []
      extras += target.eval("global_variables") if params.include?("g")

      case target_self
      when Module
        extras += target.eval("constants") if params.include?("c")
        output.puts "#{Pry.view(target.eval("local_variables + instance_variables + #{extras.inspect}"))}"
      else
        extras += target.eval("self.class.constants") if params.include?("c")
        output.puts "#{Pry.view(target.eval("local_variables + instance_variables + #{extras.inspect}"))}"
      end
    end

    command "cat", "Show output of <var>.inspect." do |obj|
      out = output
      out.puts target.eval("#{obj}.inspect")
    end
    
    command "cd", "Start a Pry session on <var> (use `cd ..` to go back)" do |obj|
      throw(:breakout, opts[:nesting].level) if obj == ".."
      target.eval("#{obj}.pry")
    end

    command "show_doc", "Show the comments above <methname>" do |meth_name|
      doc = target.eval("method(:#{meth_name})").comment
      output.puts doc
    end

    command "show_idoc", "Show the comments above instance method <methname>" do |meth_name|
      doc = target.eval("instance_method(:#{meth_name})").comment
      output.puts doc
    end

    command "show_method", "Show sourcecode for method <methname>." do |meth_name|
      context_meth_name = target.eval("__method__")
      meth_name = context_meth_name if !meth_name

      # fragile as it hard-codes in the __binding_impl__ method name
      # from core_extensions.rb
      if meth_name && meth_name != :__binding_impl__
        code = target.eval("method(\"#{meth_name.to_s}\")").source
        output.puts code
        next
      end
      output.puts "Error: Not in a method."
    end

    command "show_imethod", "Show sourcecode for instance method <methname>." do |meth_name|
      code = target.eval("instance_method(\"#{meth_name}\")").source
      output.puts code
    end

    command "show_command", "Show sourcecode for a Pry command, e.g: show_command ls" do |command_name|
      cmds = Pry.active_instance.commands.commands
      
      if cmds[command_name]
        code = cmds[command_name][:action].source
        output.puts code
      else
        output.puts "No such command: #{command_name}."
      end
    end
    
    command "jump_to", "Jump to a Pry session further up the stack, exiting all sessions below." do |break_level|
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

    command "ls_methods", "List all methods defined on class of receiver." do
      output.puts "#{Pry.view(target.eval('(public_methods(false) + private_methods(false) + protected_methods(false)).sort'))}"
    end

    command "ls_imethods", "List all instance methods defined on class of receiver." do
      output.puts "#{Pry.view(target.eval('(public_instance_methods(false) + private_instance_methods(false) + protected_instance_methods(false)).sort'))}"
    end

    command ["exit", "quit", "back"], "End the current Pry session." do
      throw(:breakout, opts[:nesting].level)
    end
  end
end
