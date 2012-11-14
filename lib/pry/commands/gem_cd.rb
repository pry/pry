class Pry
  Pry::Commands.create_command "gem-cd" do |gem|
    group 'Gems'
    description "Change working directory to specified gem's directory."
    command_options :argument_required => true

    banner <<-BANNER
      Usage: gem-cd GEM_NAME

      Change the current working directory to that in which the given gem is installed.
    BANNER

    def process(gem)
      Dir.chdir(gem_spec(gem).full_gem_path)
      output.puts(Dir.pwd)
    end

    def complete(str)
      gem_complete(str)
    end
  end
end
