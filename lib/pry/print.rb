class Pry

  # The default print object - only show first line of backtrace and
  # prepend output with `=>`
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
  
