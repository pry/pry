direc = File.dirname(__FILE__)
require "#{direc}/command_base"

class Pry
  # Default commands used by Pry.
  # @note
  #   If you plan to replace the default Commands class with a custom
  #   one then it must be a class that inherits from
  #   `Pry::CommandBase` or from `Pry::Commands` (if you want to keep
  #   default commands).
  # @example Creating a custom command set
  #   class MyCommands < Pry::CommandBase
  #     command "greeting" do
  #       describe "give a greeting"
  #       action { puts "hello world!" }
  #     end
  #
  #     command "goodbye" do
  #       describe "say goodbye and quit"
  #       action { puts "goodbye!"; exit }
  #     end
  #   end
  #
  #   Pry.commands = MyCommands
  class Commands < CommandBase
    
    command "!", "Refresh the REPL" do
      opts[:output].puts "Refreshed REPL"
      opts[:eval_string].clear
    end

    command "!pry", "Start a Pry session on current self; this even works mid-expression." do
      Pry.start(opts[:target])
    end

    command ["exit_program", "quit_program"], "End the current program." do
      exit
    end

    command "nesting", "Show nesting information." do 
      out = opts[:output]
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
      out = opts[:output]
      nesting = opts[:nesting]
      target = opts[:target]
      
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
      opts[:output].puts "#{opts[:target].eval('Pry.view(local_variables + instance_variables)')}"
    end

    command "cat", "Show output of <var>.inspect." do |obj|
      out = opts[:output]
      out.puts opts[:target].eval("#{obj}.inspect")
    end
    
    command "cd", "Start a Pry session on <var> (use `cd ..` to go back)" do |obj|
      throw(:breakout, opts[:nesting].level) if obj == ".."
      opts[:target].eval("#{obj}.pry")
    end

    command "show_doc", "Show the comments above <methname>" do |meth_name|
      doc = opts[:target].eval("method(:#{meth_name})").comment
      opts[:output].puts doc
    end

    command "show_idoc", "Show the comments above instance method <methname>" do |meth_name|
      doc = opts[:target].eval("instance_method(:#{meth_name})").comment
      opts[:output].puts doc
    end

    command "show_method", "Show sourcecode for method <methname>." do |meth_name|
      doc = opts[:target].eval("method(:#{meth_name})").source
      opts[:output].puts doc
    end

    command "show_imethod", "Show sourcecode for instance method <methname>." do |meth_name|
      doc = opts[:target].eval("instance_method(:#{meth_name})").source
      opts[:output].puts doc
    end

    command "jump_to", "Jump to a Pry session further up the stack, exiting all sessions below." do |break_level|
      break_level = break_level.to_i
      nesting = opts[:nesting]

      case break_level
      when nesting.level
        opts[:output].puts "Already at nesting level #{nesting.level}"
      when (0...nesting.level)
        throw(:breakout, break_level + 1)
      else
        max_nest_level = nesting.level - 1
        opts[:output].puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
      end
    end

    command "ls_methods", "List public methods defined on class of receiver." do
      opts[:output].puts "#{Pry.view(opts[:target].eval('public_methods(false)'))}"
    end

    command "ls_imethods", "List public instance methods defined on class of receiver." do
      opts[:output].puts "#{Pry.view(opts[:target].eval('public_instance_methods(false)'))}"
    end

    command ["exit", "quit", "back"], "End the current Pry session." do
      throw(:breakout, opts[:nesting].level)
    end
  end
end
