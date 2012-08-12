class Pry
  Pry::Commands.command "exit-program", "End the current program. Aliases: quit-program, !!!" do
    Pry.save_history if Pry.config.history.should_save
    Kernel.exit target.eval(arg_string).to_i
  end

  Pry::Commands.alias_command "quit-program", "exit-program"
  Pry::Commands.alias_command "!!!", "exit-program"
end
