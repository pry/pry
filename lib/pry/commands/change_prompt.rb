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
    if new_prompt = Pry::Prompt.get_prompt(prompt)
      _pry_.prompt = new_prompt.proc_array
    else
      raise Pry::CommandError, "'#{prompt}' isn't a known prompt!"
    end
  end

  private
  Pry::Commands.add_command(self)
end
