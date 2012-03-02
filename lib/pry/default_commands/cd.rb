class Pry
  module DefaultCommands
    Cd = Pry::CommandSet.new do
      create_command "cd" do
        group "Context"
        description "Move into a new context (object or scope)."

        banner <<-BANNER
          Usage: cd [OPTIONS] [--help]

          Move into new context (object or scope). As in unix shells use
          `cd ..` to go back and `cd /` to return to Pry top-level).
          Complex syntax (e.g cd ../@x/y) also supported.

          e.g: `cd @x`
          e.g: `cd ..
          e.g: `cd /`

          https://github.com/pry/pry/wiki/State-navigation#wiki-Changing_scope
        BANNER

        def process
          path   = arg_string.split(/\//)
          stack  = _pry_.binding_stack.dup

          # special case when we only get a single "/", return to root
          stack  = [stack.first] if path.empty?

          path.each do |context|
            begin
              case context.chomp
              when ""
                stack = [stack.first]
              when "::"
                stack.push(TOPLEVEL_BINDING)
              when "."
                next
              when ".."
                unless stack.size == 1
                  stack.pop
                end
              else
                stack.push(Pry.binding_for(stack.last.eval(context)))
              end

            rescue RescuableException => e
              output.puts "Bad object path: #{arg_string.chomp}. Failed trying to resolve: #{context}"
              output.puts e.inspect
              return
            end
          end

          _pry_.binding_stack = stack
        end
      end
    end
  end
end
