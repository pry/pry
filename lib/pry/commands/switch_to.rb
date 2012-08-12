class Pry
  Pry::Commands.command "switch-to", "Start a new sub-session on a binding in the current stack (numbered by nesting)." do |selection|
    selection = selection.to_i

    if selection < 0 || selection > _pry_.binding_stack.size - 1
      raise CommandError, "Invalid binding index #{selection} - use `nesting` command to view valid indices."
    else
      Pry.start(_pry_.binding_stack[selection])
    end
  end
end
