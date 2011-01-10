class Pry

  # Default commands used by Pry.
  # @note
  #   If you plan to replace the default Commands class with a custom
  #   one then it must have a `commands` method that returns a Hash.
  class Commands
    
    # This method returns a hash that defines the commands implemented for the REPL session.
    # The hash has the following form:
    # 
    #   * Each key is a command, it should either be a String or a
    #   Regexp or an Array.
    #   * Where it is an Array, each element should be a String or a
    #   Regexp, and the elements are considered to be aliases.
    #   * Each value is the action to take for the command. The value
    #   should be a `proc`.
    #   * If the proc needs to generate output it should write to the
    #   `opts[:output]` object, as follows: `opts[:output].puts "hello world"`
    #   * When the proc is invoked it is passed parameters in the form
    #   of an options hash, the parameters are as follows:
    #   
    #     * `opts[:val]` The current line of input.
    #     * `opts[:eval_string]` The cumulative lines of input for a multi-line input.
    #     * `opts[:target]` The receiver of the Pry session.
    #     * `opts[:nesting]` The nesting level of the current Pry Session.
    #     * `opts[:output]` The `output` object for the current Pry session.
    #     * `opts[:captures]` The Regexp captures for the command (if
    #       any) - This can be used to implement command parameters.
    #       
    # @return [Hash] The commands hash.
    # @example A 'hello' command.
    #     def commands
    #       {
    #         /^hello\s*(.+)/ => proc do |opts|
    #           opts[:output].puts "hello #{opts[:captures].first}"
    #       }
    #     end
    def commands
      @commands ||= {
        "!" => proc do |opts|
          opts[:output].puts "Refreshed REPL"
          opts[:val].clear
          opts[:eval_string].clear
        end,
        "!pry" => proc do |opts|
          Pry.start(opts[:target])
          opts[:val].clear
        end,
        ["exit_program", "quit_program"] => proc do
          exit
        end,
        /^help\s*(.+)?/ => proc do |opts|
          param = opts[:captures].first
          self.show_help(opts[:output], param)
          opts[:val].clear
        end,
        "nesting" => proc do |opts|
          self.show_nesting(opts[:output], opts[:nesting])
          opts[:val].clear
        end,
        "status" => proc do |opts|
          self.show_status(opts[:output], opts[:nesting], opts[:target])
          opts[:val].clear
        end,
        "exit_all" => proc do
          throw(:breakout, 0)
        end,
        ["exit", "quit", "back", /^cd\s*\.\./] => proc do |opts|
          throw(:breakout, opts[:nesting].level)
        end,
        "ls" => proc do |opts|
          opts[:output].puts "#{opts[:target].eval('Pry.view(local_variables + instance_variables)')}"
          opts[:val].clear
        end,
        /^cat\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          opts[:output].puts opts[:target].eval("#{obj}.inspect")
          opts[:val].clear
        end,
        /^cd\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first

          throw(:breakout, opts[:nesting].level) if obj == ".."
          
          opts[:target].eval("#{obj}.pry")
          opts[:val].clear
        end,
        /^show_doc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("method(:#{meth_name})").comment
          opts[:output].puts doc
          opts[:val].clear
        end,
        /^show_idoc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("instance_method(:#{meth_name})").comment
          opts[:val].clear
        end,
        /^show_method\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("method(:#{meth_name})").source
          opts[:output].puts code
          opts[:val].clear
        end,
        /^show_imethod\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("instance_method(:#{meth_name})").source
          opts[:val].clear
        end,
        /^jump_to\s*(\d*)/ => proc do |opts|
          break_level = opts[:captures].first.to_i
          nesting = opts[:nesting]

          case break_level
          when nesting.level
            opts[:output].puts "Already at nesting level #{nesting.level}"
            opts[:val].clear
          when (0...nesting.level)
            throw(:breakout, break_level + 1)
          else
            max_nest_level = nesting.level - 1
            opts[:output].puts "Invalid nest level. Must be between 0 and #{max_nest_level}. Got #{break_level}."
            opts[:val].clear
          end
        end,
        "ls_methods" => proc do |opts|
          opts[:output].puts "#{Pry.view(opts[:target].eval('public_methods(false)'))}"
          opts[:val].clear
        end,
        "ls_imethods" => proc do |opts|
          opts[:output].puts "#{Pry.view(opts[:target].eval('public_instance_methods(false)'))}"
          opts[:val].clear
        end
      }
    end

    def command_info
      @command_info ||= {
        "!" => "Refresh the REPL.",
        "!pry" => "Start a Pry session on current self; this even works mid-expression.",
        ["exit_program", "quit_program"] => "end the current program.",
        "help" => "This menu.",
        "nesting" => "Show nesting information.",
        "status" => "Show status information.",
        "exit_all" => "End all nested Pry sessions",
        ["exit", "quit", "back", /cd\s*\.\./] => "End the current Pry session.",
        "ls" => "Show the list of vars in the current scope.",
        "cat" => "Show output of <var>.inspect",
        "cd" => "Start a Pry session on <var> (use `cd ..` to go back)",
        "show_doc" => "Show the comments above <methname>",
        "show_idoc" => "Show the comments above instance method <methname>",
        "show_method" => "Show sourcecode for method <methname>",
        "show_imethod" => "Show sourcecode for instance method <methname>",
        "jump_to" => "Jump to a Pry session further up the stack, exiting all sessions below.",
        "ls_methods" => "List public methods defined on class of receiver.",
        "ls_imethods" => "List public instance methods defined on receiver."
      }
    end

    def show_help(out, param)
      if !param
        out.puts "Command list:"
        out.puts "--"
        command_info.each do |k, v|
          puts "#{Array(k).first}".ljust(18) + v
        end
      else
        key = command_info.keys.find { |v| Array(v).any? { |k| k === param } }
        if key
          out.puts command_info[key]
        else
          out.puts "No info for command: #{param}"
        end
      end
    end

    def show_nesting(out, nesting)
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

    def show_status(out, nesting, target)
      out.puts "Status:"
      out.puts "--"
      out.puts "Receiver: #{Pry.view(target.eval('self'))}"
      out.puts "Nesting level: #{nesting.level}"
      out.puts "Local variables: #{Pry.view(target.eval('local_variables'))}"
      out.puts "Pry instance: #{Pry.active_instance}"
      out.puts "Last result: #{Pry.view(Pry.last_result)}"
    end
  end
end
