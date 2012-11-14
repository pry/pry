class Pry
  Pry::Commands.create_command "gem-open" do |gem|
    group 'Gems'
    description "Opens the working directory of the gem in your editor"
    command_options :argument_required => true

    banner <<-BANNER
      Usage: gem-open GEM_NAME

      Change the current working directory to that in which the given gem is installed,
      and then opens your text editor.
    BANNER

    def process(gem)
      specs = Gem::Specification.respond_to?(:each) ? Gem::Specification.find_all_by_name(gem) : Gem.source_index.find_name(gem)
      spec  = specs.sort { |a,b| Gem::Version.new(b.version) <=> Gem::Version.new(a.version) }.first
      if spec
        Dir.chdir(spec.full_gem_path) do
          invoke_editor(".", 0, false)
        end
      else
        raise CommandError, "Gem `#{gem}` not found."
      end
    end
  end
end
