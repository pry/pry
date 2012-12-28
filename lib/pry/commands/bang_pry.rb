class Pry
  class Command::BangPry < Pry::ClassCommand
    match '!pry'
    group 'Navigating Pry'
    description 'Start a Pry session on current self; this even works mid ' \
      'multi-line expression.'

    def process
      target.pry
    end
  end

  Pry::Commands.add_command(Pry::Command::BangPry)
end
