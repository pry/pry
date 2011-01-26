direc = File.dirname(__FILE__)
require "#{direc}/command_base"

class Pry

  # Default commands used by Pry.
  class Commands < CommandBase
    
    command "!", "Refresh the REPL" do
      output.puts "Refreshed REPL"
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
          out.puts "#{level}. #{Pry.view(obj)} (Pry top level)"
        else
          out.puts "#{level}. #{Pry.view(obj)}"
        end
      end
    end

    command "status", "Show status information." do
      out = output
      nesting = opts[:nesting]
      
      out.puts "Status:"
      out.puts "--"
      out.puts "Receiver: #{Pry.view(target.eval('self'))}"
      out.puts "Nesting level: #{nesting.level}"
      out.puts "Local variables: #{Pry.view(target.eval('local_variables'))}"
      out.puts "Pry instance: #{Pry.active_instance}"
      out.puts "Last result: #{Pry.view(Pry.last_result)}"
    end

    command "exit_all", "End all nested Pry sessions." do
      throw(:breakout, 0) 
    end

    command "ls", "Show the list of vars in the current scope." do
      output.puts "#{Pry.view(target.eval('local_variables + instance_variables'))}"
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
      meth_name = target.eval("__method__").to_s if !meth_name
      puts "blah #{meth_name.to_s}"
      doc = target.eval("method(\"#{meth_name}\")").source
      output.puts doc
    end

    command "show_imethod", "Show sourcecode for instance method <methname>." do |meth_name|
      doc = target.eval("instance_method(#{meth_name})").source
      output.puts doc
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
      output.puts "#{Pry.view(target.eval('public_methods(false) + private_methods(false) + protected_methods(false)'))}"
    end

    command "ls_imethods", "List all instance methods defined on class of receiver." do
      output.puts "#{Pry.view(target.eval('public_instance_methods(false) + private_instance_methods(false) + protected_instance_methods(false)'))}"
    end

    command ["exit", "quit", "back"], "End the current Pry session." do
      throw(:breakout, opts[:nesting].level)
    end
  end
end
