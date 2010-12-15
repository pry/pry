class Pry
  class Output
    def refresh
      puts "Refreshed REPL"
    end

    def session_start(obj)
      puts "Beginning Pry session for #{Pry.view(obj)}"
    end

    def session_end(obj)
      puts "Ending Pry session for #{Pry.view(obj)}"
    end

    # the print component of READ-EVAL-PRINT-LOOP
    def print(value)
      case value
      when Exception
        puts "#{value.class}: #{value.message}"
      else
        puts "=> #{Pry.view(value)}"
      end
    end

    def show_help
      puts "Command list:"
      puts "--"
      puts "help                             This menu"
      puts "status                           Show status information"
      puts "!                                Refresh the REPL"
      puts "nesting                          Show nesting information"
      puts "exit/quit/back                   End the current Pry session"
      puts "exit_all                         End all nested Pry sessions"
      puts "exit_program/quit_program        End the current program"
      puts "jump_to <level>                  Jump to a Pry session further up the stack, exiting all sessions below"
    end

    def show_nesting(nesting)
      puts "Nesting status:"
      puts "--"
      nesting.each do |level, obj|
        if level == 0
          puts "#{level}. #{Pry.view(obj)} (Pry top level)"
        else
          puts "#{level}. #{Pry.view(obj)}"
        end
      end
    end

    def show_status(nesting, target)
      puts "Status:"
      puts "--"
      puts "Receiver: #{Pry.view(target.eval('self'))}"
      puts "Nesting level: #{nesting.level}"
      puts "Local variables: #{Pry.view(target.eval("local_variables"))}"
      puts "Last result: #{Pry.view(Pry.last_result)}"
    end

    def show_method(code)
      code.display
    end

    def warn_already_at_level(nesting_level)
      puts "Already at nesting level #{nesting_level}"
    end
    
    def err_invalid_nest_level(nest_level, max_nest_level)
      puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{nest_level}."
    end

    def exit() end
    def jump_to(nesting_level_breakout) end
    def exit_program() end
  end
end
