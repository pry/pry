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
      specs = Gem::Specification.respond_to?(:each) ? Gem::Specification.find_all_by_name(gem) : Gem.source_index.find_name(gem)
      spec  = specs.sort { |a,b| Gem::Version.new(b.version) <=> Gem::Version.new(a.version) }.first
      if spec
        Dir.chdir(spec.full_gem_path)
        output.puts(Dir.pwd)
      else
        raise CommandError, "Gem `#{gem}` not found."
      end
    end
  end
end
