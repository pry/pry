class Pry
  Pry::Commands.command "nesting", "Show nesting information." do
    output.puts "Nesting status:"
    output.puts "--"
    _pry_.binding_stack.each_with_index do |obj, level|
      if level == 0
        output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))} (Pry top level)"
      else
        output.puts "#{level}. #{Pry.view_clip(obj.eval('self'))}"
      end
    end
  end
end
