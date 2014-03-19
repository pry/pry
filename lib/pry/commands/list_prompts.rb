class Pry::Command::ListPrompts < Pry::ClassCommand
  match 'list-prompts'
  group 'prompts'
  description 'list the prompts available for use in pry'
  banner <<-BANNER
    Usage: list-prompts
    list the prompts available for use in pry
  BANNER

  def process
    output.puts heading("Available prompts") + "\n"
    prompt_map.each do |name, prompt|
      output.write "name: #{text.bold(name)}"
      output.puts selected_prompt?(prompt) ? selected_text : ""
      output.puts prompt[:description]
      output.puts
    end
  end

private
  def prompt_map
    Pry::Prompt::MAP
  end

  def selected_text
    text.red " (selected) "
  end

  def selected_prompt?(prompt)
    _pry_.prompt == prompt[:value]
  end
  Pry::Commands.add_command(self)
end
