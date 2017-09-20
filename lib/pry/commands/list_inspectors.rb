class Pry::Command::ListInspectors < Pry::ClassCommand
  match 'list-inspectors'
  group 'Inspectors'
  description 'List the inspector that are available to use.'
  banner <<-BANNER
    Usage: list-inspectors

    List the inspectors available for displaying an object that's returned
    by Kernel.eval().
  BANNER

  def process
    output.puts heading("Available inspectors") + "\n"
    inspector_map.each do |name, inspector|
      output.write "Name: #{text.bold(name)}"
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
