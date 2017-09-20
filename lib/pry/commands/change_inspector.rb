class Pry::Command::ChangeInspector < Pry::ClassCommand
  match 'change-inspector'
  group 'Inspectors'
  description 'Change the current inspector.'
  command_options argument_required: true
  banner <<-BANNER
    Usage: change-inspector NAME

    Change the current inspector. See 'list-inspectors' for a complete list of
    available inspectors.
  BANNER

  def process(inspector)
    if inspector_map.key?(inspector)
      _pry_.print = inspector_map[inspector][:value]
      output.puts "Switched to '#{inspector}' inspector."
    else
      raise Pry::CommandError, "'#{inspector}' isn't known."
    end
  end

private
  def inspector_map
    Pry::Inspector::MAP
  end
  Pry::Commands.add_command(self)
end
