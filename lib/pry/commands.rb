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
    
    command "!" do
      describe "Refresh the REPL"
      action do |opts|
        opts[:output].puts "Refreshed REPL"
        opts[:eval_string].clear
      end
    end

    command "!pry" do
      describe "Start a Pry session on current self; this even works mid-expression."      
      action do |opts|
        Pry.start(opts[:target])
      end
    end

    command ["exit_program", "quit_program"] do
      describe "End the current program."
      action { |opts| exit }
    end

    command "nesting" do
      describe "Show nesting information."

      action do |opts|
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
    end

    command "status" do
      describe "Show status information."

      action do |opts|
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
    end

    command "exit_all" do
      describe "End all nested Pry sessions."
      action { |opts| throw(:breakout, 0) }
    end

    command "ls" do
      describe "Show the list of vars in the current scope."
      action do |opts|
        opts[:output].puts "#{opts[:target].eval('Pry.view(local_variables + instance_variables)')}"
      end
    end

    command "cat" do
      describe "Show output of <var>.inspect."
      pattern /^cat\s+(.+)/
      action do |opts|
        out = opts[:output]
        obj = opts[:captures].first

        out.puts opts[:target].eval("#{obj}.inspect")
      end
    end
    
    command "cd" do
      pattern /^cd\s+(.+)/
      describe "Start a Pry session on <var> (use `cd ..` to go back)"

      action do |opts|
        obj = opts[:captures].first
        throw(:breakout, opts[:nesting].level) if obj == ".."
        opts[:target].eval("#{obj}.pry")
      end
    end

    command "show_doc" do
      pattern /^show_doc\s*(.+)/
      describe "Show the comments above <methname>"
      action do |opts|
        meth_name = opts[:captures].first
        doc = opts[:target].eval("method(:#{meth_name})").comment
        opts[:output].puts doc
      end
    end

    command "show_idoc" do
      pattern /^show_idoc\s*(.+)/
      describe "Show the comments above instance method <methname>"
      action do |opts|
        meth_name = opts[:captures].first
        doc = opts[:target].eval("instance_method(:#{meth_name})").comment
        opts[:output].puts doc
      end
    end

    command "show_method" do
      pattern /^show_method\s*(.+)/
      describe "Show sourcecode for method <methname>."
      action do |opts|
        meth_name = opts[:captures].first
        doc = opts[:target].eval("method(:#{meth_name})").source
        opts[:output].puts doc
      end
    end

    command "show_imethod" do
      pattern /^show_imethod\s*(.+)/
      describe "Show sourcecode for instance method <methname>."
      action do |opts|
        meth_name = opts[:captures].first
        doc = opts[:target].eval("instance_method(:#{meth_name})").source
        opts[:output].puts doc
      end
    end

    command "jump_to" do
      pattern /^jump_to\s*(\d*)/

      describe "Jump to a Pry session further up the stack, exiting all sessions below."
      
      action do |opts|
        break_level = opts[:captures].first.to_i
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
    end

    command "ls_methods" do
      describe "List public methods defined on class of receiver."
      
      action do |opts|
        opts[:output].puts "#{Pry.view(opts[:target].eval('public_methods(false)'))}"
      end
    end

    command "ls_imethods" do
      describe "List public instance methods defined on class of receiver."
      
      action do |opts|
        opts[:output].puts "#{Pry.view(opts[:target].eval('public_instance_methods(false)'))}"
      end
    end

    command ["exit", "quit", "back"] do
      describe "End the current Pry session."
      action do |opts|
         throw(:breakout, opts[:nesting].level)
      end
    end
  end
end
