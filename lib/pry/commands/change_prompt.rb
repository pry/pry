class Pry::Command::ChangePrompt < Pry::ClassCommand
  match 'change-prompt'
  group 'Input and Output'
  description 'Change the current prompt.'
  command_options argument_required: true
  banner <<-BANNER
    Usage: change-prompt NAME

    Change the current prompt. See list-prompts for a list of available
    prompts.
  BANNER

  def process(prompt)
    if Pry::Prompt.all.key?(prompt)
      _pry_.prompt = Pry::Prompt.all[prompt][:value]
    else
      raise Pry::CommandError, "'#{prompt}' isn't a known prompt!"
    end
  end

  Pry::Commands.add_command(self)
end
