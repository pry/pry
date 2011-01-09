class Object
  def test_method
  end
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

class CommandTester
  def commands
    @commands ||= {
      "command1" => proc { |opts| opts[:output].puts "command1"; opts[:val].clear },
      /command2\s*(.*)/ => proc do |opts|
        arg = opts[:captures].first
        opts[:output].puts arg
        opts[:val].clear
      end
    }
  end
end
