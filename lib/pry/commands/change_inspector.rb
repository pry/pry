class Pry::Command::ChangeInspector < Pry::ClassCommand
  match 'change-inspector'
  group 'inspect'
  description 'change the current pry inspector'
  command_options argument_required: true
  banner <<-BANNER
    Usage: change-inspector
    change the Proc to used to print return values in a repl session.
    see list-inspectors for a list of available Proc's and a short description
    of what they do.
  BANNER

  def process(inspector)
    if inspector_map.key?(inspector)
      _pry_.print = inspector_map[inspector][:value]
      output.puts "switched to the '#{inspector}' inspector!"
    else
      raise Pry::CommandError, "'#{inspector}' isn't a known inspector!"
    end
  end

private
  def inspector_map
    Pry::Inspector::MAP
  end
  Pry::Commands.add_command(self)
end
