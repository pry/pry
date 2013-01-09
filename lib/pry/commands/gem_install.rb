class Pry
  class Command::GemInstall < Pry::ClassCommand
    match 'gem-install'
    group 'Gems'
    description 'Install a gem and refresh the gem cache.'
    command_options :argument_required => true

    banner <<-'BANNER'
      Usage: gem-install GEM_NAME

      Installs the given gem and refreshes the gem cache so that you can immediately
      'require GEM_FILE'.

      gem-install pry-stack_explorer
    BANNER

    def setup
      require 'rubygems/dependency_installer' unless defined? Gem::DependencyInstaller
    end

    def process(gem)
      Rubygem.install(gem)
      output.puts "Gem `#{ text.green(gem) }` installed."
      require gem
    end
  end

  Pry::Commands.add_command(Pry::Command::GemInstall)
end
