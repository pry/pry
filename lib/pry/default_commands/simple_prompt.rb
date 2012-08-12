class Pry
  Pry::Commands.command "simple-prompt", "Toggle the simple prompt." do
    case _pry_.prompt
    when Pry::SIMPLE_PROMPT
      _pry_.pop_prompt
    else
      _pry_.push_prompt Pry::SIMPLE_PROMPT
    end
  end
end
