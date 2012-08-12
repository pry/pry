class Pry
  Pry::Commands.create_command "simple-prompt" do
    group 'Misc'
    description "Toggle the simple prompt."

    def process
      case _pry_.prompt
      when Pry::SIMPLE_PROMPT
        _pry_.pop_prompt
      else
        _pry_.push_prompt Pry::SIMPLE_PROMPT
      end
    end
  end
end
