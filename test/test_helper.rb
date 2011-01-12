class Module
  public :remove_const
end

class InputTester
  def initialize(*actions)
    @orig_actions = actions.dup
    @actions = actions
  end

  def readline(*)
    @actions.shift
  end

  def rewind
    @actions = @orig_actions.dup
  end
end

class CommandTester < Pry::CommandBase

  command "command1" do
    describe "command 1 test"
    action { |opts| opts[:output].puts "command1"; opts[:val].clear }
  end

  command "command2" do
    describe "command 2 test"
    pattern /command2\s*(.*)/
    action { |opts|
      arg = opts[:captures].first
      opts[:output].puts arg
      opts[:val].clear
    }
  end
  
  
  #   def commands
  #     @commands ||= {
  #       "command1" => proc { |opts| opts[:output].puts "command1"; opts[:val].clear },
  #       /command2\s*(.*)/ => proc do |opts|
  #         arg = opts[:captures].first
  #         opts[:output].puts arg
  #         opts[:val].clear
  #       end
  #     }
  #   end
  # e
end
