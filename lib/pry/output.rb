class Pry
  class Output
    attr_reader :out
    
    def initialize(out=STDOUT)
      @out = out
    end

    def puts(value)
      out.puts value
    end
    
    def refresh
      out.puts "Refreshed REPL"
    end

    def session_start(obj)
      out.puts "Beginning Pry session for #{Pry.view(obj)}"
    end

    def session_end(obj)
      out.puts "Ending Pry session for #{Pry.view(obj)}"
    end

    # the print component of READ-EVAL-PRINT-LOOP
    def print(value)
      case value
      when Exception
        out.puts "#{value.class}: #{value.message}"
      else
        out.puts "=> #{Pry.view(value)}"
      end
    end

    def show_help
      out.puts "Command list:"
      out.puts "--"
      out.puts "help                             This menu"
      out.puts "status                           Show status information"
      out.puts "!                                Refresh the REPL"
      out.puts "nesting                          Show nesting information"
      out.puts "ls                               Show the list of variables in the current scope"
      out.puts "cat <var>                        Show output of <var>.inspect"
      out.puts "cd <var>                         Start a Pry session on <var> (use `cd ..` to go back)"
      out.puts "show_method <methname>           Show the sourcecode for the method <methname>"
      out.puts "show_imethod <methname>          Show the sourcecode for the instance method <method_name>"
      out.puts "show_doc <methname>              Show the comments above <methname>"
      out.puts "show_idoc <methname>             Show the comments above instance method <methname>"
      out.puts "exit/quit/back                   End the current Pry session"
      out.puts "exit_all                         End all nested Pry sessions"
      out.puts "exit_program/quit_program        End the current program"
      out.puts "jump_to <level>                  Jump to a Pry session further up the stack, exiting all sessions below"
    end

    def show_nesting(nesting)
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

    def show_status(nesting, target)
      out.puts "Status:"
      out.puts "--"
      out.puts "Receiver: #{Pry.view(target.eval('self'))}"
      out.puts "Nesting level: #{nesting.level}"
      out.puts "Local variables: #{target.eval('Pry.view(local_variables)')}"
      out.puts "Last result: #{Pry.view(Pry.last_result)}"
    end

    def ls(target)
      out.puts "#{target.eval('Pry.view(local_variables + instance_variables)')}"
    end

    def cat(target, var)
      out.puts target.eval("#{var}.inspect")
    end
    
    def show_method(code)
      out.puts code
    end

    def show_doc(doc)
      out.puts doc
    end

    def warn_already_at_level(nesting_level)
      out.puts "Already at nesting level #{nesting_level}"
    end
    
    def err_invalid_nest_level(nest_level, max_nest_level)
      out.puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{nest_level}."
    end

    def exit() end
    def cd(*) end
    def jump_to(nesting_level_breakout) end
    def exit_program() end
  end
end
