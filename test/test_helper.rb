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

  command "command1", "command 1 test" do
    opts[:output].puts "command1"
    opts[:val].clear 
  end

  command "command2", "command 2 test" do |arg|
    opts[:output].puts arg
    opts[:val].clear
  end
end
