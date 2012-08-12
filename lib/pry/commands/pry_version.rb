class Pry
  Pry::Commands.create_command "pry-version" do
    group 'Misc'
    description "Show Pry version."

    def process
      output.puts "Pry version: #{Pry::VERSION} on Ruby #{RUBY_VERSION}."
    end
  end
end
