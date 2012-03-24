require "pry/default_commands/ls"
require "pry/default_commands/cd"

class Pry
  module DefaultCommands

    Context = Pry::CommandSet.new do
      import Ls
      import Cd

      command "whereami", "Show the code context for the session. (whereami <n> shows <n> extra lines of code around the invocation line. Default: 5)" do |num|
        file, line_num = file_and_line_from_binding(target)
        i_num = num ? num.to_i : 5

        if file != Pry.eval_path && (file =~ /(\(.*\))|<.*>/ || file == "" || file == "-e")
          raise CommandError, "Cannot find local context. Did you use binding.pry?"
        end

        set_file_and_dir_locals(file)

        method = Pry::Method.from_binding(target)
        method_description = method ? " in #{method.name_with_owner}" : ""
        output.puts "\n#{text.bold('From:')} #{file} @ line #{line_num}#{method_description}:\n\n"

        code = Pry::Code.from_file(file).around(line_num, i_num)
        output.puts code.with_line_numbers.with_marker(line_num)
        output.puts
      end

      create_command "pry-backtrace", "Show the backtrace for the Pry session." do
        banner <<-BANNER
          Usage:   pry-backtrace [OPTIONS] [--help]

          Show the backtrace for the position in the code where Pry was started. This can be used to
          infer the behavior of the program immediately before it entered Pry, just like the backtrace
          property of an exception.

          (NOTE: if you are looking for the backtrace of the most recent exception raised,
          just type: `_ex_.backtrace` instead, see https://github.com/pry/pry/wiki/Special-Locals)

          e.g: pry-backtrace
        BANNER

        def process
          output.puts "\n#{text.bold('Backtrace:')}\n--\n"
          stagger_output _pry_.backtrace.join("\n")
        end
      end

      command "reset", "Reset the REPL to a clean state." do
        output.puts "Pry reset."
        exec "pry"
      end

      create_command /wtf([?!]*)/, "Show the backtrace of the most recent exception" do
        options :listing => 'wtf?'

        banner <<-BANNER
          Show's a few lines of the backtrace of the most recent exception (also available
          as _ex_.backtrace).

          If you want to see more lines, add more question marks or exclamation marks:

          e.g.
          pry(main)> wtf?
          pry(main)> wtf?!???!?!?

          To see the entire backtrace, pass the -v/--verbose flag:

          e.g.
          pry(main)> wtf -v
        BANNER

        def options(opt)
          opt.on(:v, :verbose, "Show the full backtrace.")
        end

        def process
          raise Pry::CommandError, "No most-recent exception" unless _pry_.last_exception

          output.puts "#{text.bold('Exception:')} #{_pry_.last_exception.class}: #{_pry_.last_exception}\n--"
          if opts.verbose?
            output.puts Code.new(_pry_.last_exception.backtrace, 0, :text).with_line_numbers.to_s
          else
            output.puts Code.new(_pry_.last_exception.backtrace.first([captures[0].size, 0.5].max * 10), 0, :text).with_line_numbers.to_s
          end
        end
      end

      # N.B. using a regular expresion here so that "raise-up 'foo'" does the right thing.
      create_command /raise-up(!?\b.*)/, :listing => 'raise-up' do
        description "Raise an exception out of the current pry instance."
        banner <<-BANNER
          Raise up, like exit, allows you to quit pry. Instead of returning a value however, it raises an exception.
          If you don't provide the exception to be raised, it will use the most recent exception (in pry _ex_).

          e.g. `raise-up "get-me-out-of-here"` is equivalent to:
               `raise "get-me-out-of-here"
                raise-up`

          When called as raise-up! (with an exclamation mark), this command raises the exception through
          any nested prys you have created by "cd"ing into objects.
        BANNER

        def process
          return stagger_output help if captures[0] =~ /(-h|--help)\b/
          # Handle 'raise-up', 'raise-up "foo"', 'raise-up RuntimeError, 'farble' in a rubyesque manner
          target.eval("_pry_.raise_up#{captures[0]}")
        end
      end
    end
  end
end
