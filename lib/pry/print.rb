require "awesome_print"

class Pry
  DEFAULT_PRINT = proc do |output, value|
    if Pry.color
      output.puts "=> #{value.ai}"#"#{CodeRay.scan(Pry.view(value), :ruby).term}"
    else
      output.puts "=> #{Pry.view(value)}"
    end
  end

  # Will only show the first line of the backtrace
  DEFAULT_EXCEPTION_HANDLER = proc do |output, exception|
    output.puts "#{exception.class}: #{exception.message}"
    output.puts "from #{exception.backtrace.first}"
  end
end

