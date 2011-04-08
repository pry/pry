# Ensure we do not execute any rc files
Pry::RC_FILES.clear
Pry.color = false
Pry.should_load_rc = false

class Module
  public :remove_const
end

class << Pry
  alias_method :orig_reset_defaults, :reset_defaults
  def reset_defaults
    orig_reset_defaults
    Pry.color = false
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

class Pry

  # null output class - doesn't write anywwhere.
  class NullOutput
    def self.puts(*) end
    def self.string(*) end
  end
end


class CommandTester < Pry::CommandBase

  command "command1", "command 1 test" do
    output.puts "command1"
  end

  command "command2", "command 2 test" do |arg|
    output.puts arg
  end
end
