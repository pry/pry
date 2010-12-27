class Pry
  DEFAULT_PRINT = proc do |output, value|
    case value
    when Exception
      output.puts "#{value.class}: #{value.message}"
      output.puts "from #{value.backtrace.first}"
    else
      output.puts "=> #{Pry.view(value)}"
    end
  end
end
  
