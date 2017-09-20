class Pry
  class Command::SimplePrompt < Pry::ClassCommand
    match 'simple-prompt'
    group 'Prompts'
    description 'Toggle the simple prompt.'

    banner <<-'BANNER'
      Toggle between current prompt and the 'simple' prompt.
    BANNER

    def process
      case _pry_.prompt
      when Pry::Prompt['simple']
        _pry_.pop_prompt
      else
        _pry_.push_prompt Pry::Prompt['simple']
      end
    end
    Pry::Commands.add_command(self)
  end
end
