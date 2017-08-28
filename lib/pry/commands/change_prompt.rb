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
    prompts = Pry::Prompt.all(prompt)
    if prompts.size == 1
      _pry_.prompt = prompts[0].proc_array
    elsif prompts.size > 1
      multiple_choice(prompts)
    else
      raise Pry::CommandError, "'#{prompt}' isn't a known prompt!"
    end
  end

  private
  def multiple_choice(prompts)
    _pry_.pager.page "Multiple aliases found, please choose:\n"
    prompts.each.with_index(1) do |prompt, i|
      _pry_.pager.page "#{i}) #{prompt.name} => #{prompt.alias_for}"
    end
    output.write "Choice: "
    reply = _pry_.input.respond_to?(:gets) ? _pry_.input.gets : _pry_.input.readline
    if reply =~ /^[1-9]+$/ and reply.to_i <= prompts.size
      _pry_.prompt = prompts[reply.to_i-1].proc_array
    else
      multiple_choice(prompts)
    end
  end
  Pry::Commands.add_command(self)
end
