require "pry/default_commands/ls"

class Pry
  module DefaultCommands

    Context = Pry::CommandSet.new do
      import Ls

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

        Pry.start target.eval(opts[:arg_string])
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
        str = remove_first_word(opts[:val])
        throw(:breakout, [opts[:nesting].level, target.eval(str)])
      end

      alias_command "quit", "exit", ""
      alias_command "back", "exit", ""

      command "exit-all", "End all nested Pry sessions. Accepts optional return value. Aliases: !!@" do
        str = remove_first_word(opts[:val])
        throw(:breakout, [0, target.eval(str)])
      end

      alias_command "!!@", "exit-all", ""

      command "exit-program", "End the current program. Aliases: quit-program, !!!" do
        exit
      end

      alias_command "quit-program", "exit-program", ""
      alias_command "!!!", "exit-program", ""

      command "!pry", "Start a Pry session on current self; this even works mid-expression." do
        Pry.start(target)
      end

      command "whereami", "Show the code context for the session. (whereami <n> shows <n> extra lines of code around the invocation line. Default: 5)" do |num|
        file = target.eval('__FILE__')
        line_num = target.eval('__LINE__')
        klass = target.eval('self.class')

        if num
          i_num = num.to_i
        else
          i_num = 5
        end

        meth_name = meth_name_from_binding(target)
        meth_name = "N/A" if !meth_name

        if file =~ /(\(.*\))|<.*>/ || file == "" || file == "-e"
          output.puts "Cannot find local context. Did you use `binding.pry` ?"
          next
        end

        set_file_and_dir_locals(file)
        output.puts "\n#{text.bold('From:')} #{file} @ line #{line_num} in #{klass}##{meth_name}:\n\n"

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

    end
  end
end
