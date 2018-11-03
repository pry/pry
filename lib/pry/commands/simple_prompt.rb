class Pry
  class Command::SimplePrompt < Pry::ClassCommand
    match 'simple-prompt'
    group 'prompts'
    description 'Toggle the simple prompt.'

    banner <<-'BANNER'
      Toggle the simple prompt.
    BANNER

    def process
      state.disabled ^= true

      if state.disabled
        state.prev_prompt = _pry_.prompt
        _pry_.prompt = Pry::Prompt[:simple][:value]
      else
        _pry_.prompt = state.prev_prompt
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::SimplePrompt)
end
