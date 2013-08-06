class Pry
  class Command::GemUninstall < Pry::ClassCommand
    match 'gem-uninstall'
    group 'Gems'
    description 'Uninstall a gem and refresh the gem cache.'
    command_options :argument_required => true

    banner <<-'BANNER'
      Usage: gem-uninstall GEM_NAME

      Uninstalls the given gem and refreshes the gem cache

      gem-uninstall pry-stack_explorer
    BANNER

    def setup
      require 'rubygems/uninstaller' unless defined? Gem::Uninstaller
    end

    def process(gem)
      puts "Uninstalling gem #{gem}"
      Rubygem.uninstall(gem)
      output.puts "Gem `#{ text.green(gem) }` uninstalled."
    end
  end

  Pry::Commands.add_command(Pry::Command::GemUninstall)
end
