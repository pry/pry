class Pry
  class Command::Nesting < Pry::ClassCommand
    match "tree"
    group 'Navigating Pry'
    description 'Show nesting information.'

    banner <<-'BANNER'
      Show nesting information.
    BANNER

    def process
      _pry_.pager.page "maybe try the nav prompt"
    end
  end

  Pry::Commands.add_command(Pry::Command::Nesting)
end
