class Pry
  class Commands
    attr_accessor :out
    
    def initialize(out)
      @out = out
    end
    
    def commands
      @commands ||= {
        "!" => proc do |opts|
          out.puts "Refreshed REPL"
          opts[:eval_string].clear
        end,
        ["exit_program", "quit_program"] => proc do
          exit
        end,
        /^help\s*(.+)?/ => proc do |opts|
          param = opts[:captures].first
          self.show_help(param)
          opts[:eval_string].clear
        end,
        "nesting" => proc do |opts|
          self.show_nesting(opts[:nesting])
          opts[:eval_string].clear
        end,
        "status" => proc do |opts|
          self.show_status(opts[:nesting], opts[:target])
          opts[:eval_string].clear
        end,
        "exit_all" => proc do
          throw(:breakout, 0)
        end,
        ["exit", "quit", "back", "cd .."] => proc do |opts|
          throw(:breakout, opts[:nesting].level)
        end,
        "ls" => proc do |opts|
          out.puts "#{opts[:target].eval('Pry.view(local_variables + instance_variables)')}"
          opts[:eval_string].clear
        end,
        /^cat\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          out.puts opts[:target].eval("#{obj}.inspect")
          opts[:eval_string].clear
        end,
        /^cd\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          opts[:target].eval("#{obj}.pry")
          opts[:eval_string].clear
        end,
        /^show_doc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("method(:#{meth_name})").comment
          out.puts doc
          opts[:eval_string].clear
        end,
        /^show_idoc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("instance_method(:#{meth_name})").comment
          opts[:eval_string].clear
        end,
        /^show_method\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("method(:#{meth_name})").source
          out.puts code
          opts[:eval_string].clear
        end,
        /^show_imethod\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("instance_method(:#{meth_name})").source
          opts[:eval_string].clear
        end,
        /^jump_to\s*(\d*)/ => proc do |opts|
          break_level = opts[:captures].first.to_i
          nesting = opts[:nesting]

          case break_level
          when nesting.level
            out.puts "Already at nesting level #{nesting.level}"
            opts[:eval_string].clear
          when (0...nesting.level)
            throw(:breakout, break_level + 1)
          else
            max_nest_level = nesting.level - 1
            out.puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
            opts[:eval_string].clear
          end
        end
      }
    end

    def command_info
      @command_info ||= {
        "!" => "Refresh the REPL.",
        ["exit_program", "quit_program"] => "end the current program.",
        "help" => "This menu.",
        "nesting" => "Show nesting information.",
        "status" => "Show status information.",
        "exit_all" => "End all nested Pry sessions",
        ["exit", "quit", "back", "cd .."] => "End the current Pry session.",
        "ls" => "Show the list of vars in the current scope.",
        "cat" => "Show output of <var>.inspect",
        "cd" => "Start a Pry session on <var> (use `cd ..` to go back)",
        "show_doc" => "Show the comments above <methname>",
        "show_idoc" => "Show the comments above instance method <methname>",
        "show_method" => "Show sourcecode for method <methname>",
        "show_imethod" => "Show sourcecode for instance method <methname>",
        "jump_to" => "Jump to a Pry session further up the stack, exiting all sessions below."
      }
    end

    def show_help(param)
      if !param
        out.puts "Command list:"
        out.puts "--"
        command_info.each do |k, v|
          puts "#{Array(k).first}".ljust(33) + v
        end
      else
        key = command_info.keys.find { |v| Array(v).any? { |k| k == param } }
        if key
          out.puts command_info[key]
        else
          out.puts "No info for command: #{param}"
        end
      end
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
  end
end
