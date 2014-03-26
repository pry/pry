class Pry::Command::ListInspectors < Pry::ClassCommand
  match 'list-inspectors'
  group 'inspect'
  description 'list the inspector Procs available for use in pry'
  banner <<-BANNER
    Usage: list-inspectors
    list the inspector Proc's available to print ruby objects(e.g: return values) in
    a repl session.
  BANNER

  def process
    output.puts heading("Available inspectors") + "\n"
    inspector_map.each do |name, inspector|
      output.write "name: #{text.bold(name)}"
      output.puts selected_inspector?(inspector) ? selected_text : ""
      output.puts inspector[:description]
      output.puts
    end
  end

private
  def inspector_map
    Pry::Inspector::MAP
  end

  def selected_text
    text.red " (selected) "
  end

  def selected_inspector?(inspector)
    _pry_.print == inspector[:value]
  end
  Pry::Commands.add_command(self)
end
