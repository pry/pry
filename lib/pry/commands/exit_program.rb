class Pry
  class Command::ExitProgram < Pry::ClassCommand
    match 'exit-program'
    group 'Navigating Pry'
    description 'End the current program. Aliases: quit-program, !!!'

    def process
      Pry.save_history if Pry.config.history.should_save
      Kernel.exit target.eval(arg_string).to_i
    end
  end

  Pry::Commands.add_command(Pry::Command::ExitProgram)
  Pry::Commands.alias_command 'quit-program', 'exit-program'
  Pry::Commands.alias_command '!!!', 'exit-program'
end
