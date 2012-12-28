class Pry
  class Command::Reset < Pry::ClassCommand
    match 'reset'
    group 'Context'
    description 'Reset the REPL to a clean state.'

    def process
      output.puts 'Pry reset.'
      exec 'pry'
    end
  end

  Pry::Commands.add_command(Pry::Command::Reset)
end
