module Pry
  class Output
    def refresh
      puts "Refreshed REPL"
    end

    def session_start(obj)
      puts "Beginning Pry session for #{obj.inspect}"
    end

    def session_end(obj)
      puts "Ending Pry session for #{obj.inspect}"
    end

    # the print component of READ-EVAL-PRINT-LOOP
    def print(value)
      case value
      when Exception
        puts "#{value.class}: #{value.message}"
      else
        puts "=> #{value.inspect}"
      end
    end

    def show_nesting(nesting)
      puts "Nesting status:"
      nesting.each do |level, obj|
        if level == 0
          puts "#{level}. #{obj.inspect} (Pry top level)"
        else
          puts "#{level}. #{obj.inspect}"
        end
      end
    end

    def error_invalid_nest_level(nest_level, max_nest_level)
      puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{nest_level}."
    end

    def exit() end
    def exit_at(nesting_level_breakout) end
    def exit_program() end
  end
end
