class Pry
  class Commands
    attr_reader :commands, :output
    
    def initialize(out)
      @output = out
      
      @commands = {
        ["exit_program", "quit_program"] => proc { opts[:output].exit_program; exit },
        "!" => proc { |opts| opts[:output].refresh; opts[:eval_string].clear },
        "help" => proc { |opts| opts[:output].show_help; opts[:eval_string].clear },
        "nesting" => proc { |opts| opts[:output].show_nesting(opts[:nesting]); opts[:eval_string].clear },
        "status" => proc do |opts|
          opts[:output].show_status(opts[:nesting], opts[:target])
          opts[:eval_string].clear
        end,
        "exit_all" => proc { throw(:breakout, 0) },
        ["exit", "quit", "back", "cd .."] => proc do |opts|
          output.exit
          throw(:breakout, opts[:nesting].level)
        end,
        "ls" => proc do |opts|
          opts[:output].ls(opts[:target])
          opts[:eval_string].clear
        end,
        /^cat\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          opts[:output].cat(opts[:target], obj)
          opts[:eval_string].clear
        end,
        /^cd\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          opts[:target].eval("#{obj}.pry")
          opts[:output].cd obj
          opts[:eval_string].clear
        end,
        /^show_doc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("method(:#{meth_name})").comment
          opts[:output].show_doc doc
          opts[:eval_string].clear
        end,
        /^show_idoc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("instance_method(:#{meth_name})").comment
          opts[:output].show_doc doc
          opts[:eval_string].clear
        end,
        /^show_method\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("method(:#{meth_name})").source
          opts[:output].show_method code
          opts[:eval_string].clear
        end,
        /^show_imethod\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("instance_method(:#{meth_name})").source
          output.show_method code
          opts[:eval_string].clear
        end,
        /^jump_to\s*(\d*)/ => proc do |opts|
          break_level = opts[:captures].first.to_i
          opts[:output].jump_to(break_level)
          nesting = opts[:nesting]

          case break_level
          when nesting.level
            opts[:output].warn_already_at_level(nesting.level)
            opts[:eval_string].clear
          when (0...nesting.level)
            throw(:breakout, break_level + 1)
          else
            opts[:output].err_invalid_nest_level(break_level,
                                          nestingn.level - 1)
            opts[:eval_string].clear
          end
        end
        }
    end
  end
end
  
