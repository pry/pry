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
      Dir.chdir(gem_spec(gem).full_gem_path) do
        invoke_editor(".", 0, false)
      end
    end
  end
end
