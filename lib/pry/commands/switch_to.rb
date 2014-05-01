class Pry
  class Command::SwitchTo < Pry::ClassCommand
    match 'switch-to'
    group 'Navigating Pry'
    description 'switch the active index stored in the binding stack'

    banner <<-'BANNER'
      switch-to X

      switch the active index stored in the binding stack.
      the stack is accessible at `_pry_.bstack` from a repl session.
    BANNER

    def process(index)
      _pry_.bstack.switch_to Integer(index)
    end
  end

  Pry::Commands.add_command(Pry::Command::SwitchTo)
end
