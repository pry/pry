class Pry
  Pry::Commands.command "exit-all", "End the current Pry session (popping all bindings) and returning to caller. Accepts optional return value. Aliases: !!@" do
    # calculate user-given value
    exit_value = target.eval(arg_string)

    # clear the binding stack
    _pry_.binding_stack.clear

    # break out of the repl loop
    throw(:breakout, exit_value)
  end

  Pry::Commands.alias_command "!!@", "exit-all"
end
