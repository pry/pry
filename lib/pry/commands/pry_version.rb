class Pry
  Pry::Commands.command "pry-version", "Show Pry version." do
    output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
  end
end
