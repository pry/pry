class Pry
  class Commands
    def initialize(val, eval_string, target, output)
      @commands = {
        "exit_program" => proc { output.exit_program; exit },
        "!" => proc { |opts| output.refresh; opts[:eval_string].clear },
        "help" => proc { |opts| output.show_help; opts[:eval_string].clear },
        "nesting" => proc { |opts| output.show_nesting(opts[:nesting]); opts[:eval_string].clear },
        "status" => proc do |opts|
          output.show_status(opts[:nesting], opts[:target])
          eval_string.clear
        end,
        "exit_all" => proc { throw(:breakout, 0) },
        "exit" => proc do
          output.exit
          throw(:breakout, opts[:nesting].level)
        end,
        "ls" => proc do |opts|
          output.ls(opts[:target])
          opts[:eval_string].clear
        end,
        /^cat\s+(.+)/ => proc do |opts|
          obj = opts[:captures].first
          output.cat(opts[:target], obj)
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
          output.show_doc doc
          opts[:eval_string].clear
        end,
        /^show_idoc\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          doc = opts[:target].eval("instance_method(:#{meth_name})").comment
          output.show_doc doc
          opts[:eval_string].clear
        end,
        /^show_method\s*(.+)/ => proc do |opts|
          meth_name = opts[:captures].first
          code = opts[:target].eval("method(:#{meth_name})").source
          output.show_method code
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
          output.jump_to(break_level)
          nesting = opts[:nesting]

          case break_level
          when nesting.level
            output.warn_already_at_level(nesting.level)
            opts[:eval_string].clear
          when (0...nesting.level)
            throw(:breakout, break_level + 1)
          else
            output.err_invalid_nest_level(break_level,
                                      nesting.level - 1)
            opts[:eval_string].clear
          end
        end
      end
    end
    
    def process_commands(val, eval_string, target)
      
    end
  end
end
  
