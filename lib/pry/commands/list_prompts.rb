class Pry::Command::ListPrompts < Pry::ClassCommand
  match 'list-prompts'
  group 'Input and Output'
  description 'List the prompts available for use.'
  banner <<-BANNER
    Usage: list-prompts

    List the available prompts. You can use change-prompt to switch between
    them.
  BANNER

  def process
    output.puts heading("Available prompts") + "\n"
    Pry::Prompt.all.each do |name, prompt|
      output.write "Name: #{bold(name)}"
      output.puts selected_prompt?(prompt) ? selected_text : ""
      output.puts prompt[:description]
      output.puts
    end
  end

  private

  def selected_text
    red " (selected) "
  end

  def selected_prompt?(prompt)
    _pry_.prompt == prompt[:value]
  end
  Pry::Commands.add_command(self)
end
