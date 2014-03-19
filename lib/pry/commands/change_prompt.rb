class Pry::Command::ChangePrompt < Pry::ClassCommand
  match 'change-prompt'
  group 'prompts'
  description 'change the current pry prompt'
  command_options argument_required: true
  banner <<-BANNER
    Usage: change-prompt
    change the current prompt. see list-prompts for a list of available prompts.
  BANNER

  def process(prompt)
    if prompt_map.key?(prompt)
      _pry_.prompt = prompt_map[prompt][:value]
    else
      raise Pry::CommandError, "'#{prompt}' isn't a known prompt!"
    end
  end

private
  def prompt_map
    Pry::Prompt::MAP
  end
  Pry::Commands.add_command(self)
end
