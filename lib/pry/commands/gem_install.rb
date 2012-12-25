class Pry
  class Command::GemInstall < Pry::ClassCommand
    match 'gem-install'
    group 'Gems'
    description 'Install a gem and refresh the gem cache.'
    command_options :argument_required => true

    banner <<-BANNER
      Usage: gem-install GEM_NAME

      Installs the given gem and refreshes the gem cache so that you can immediately 'require GEM_FILE'
    BANNER

    def setup
      require 'rubygems/dependency_installer' unless defined? Gem::DependencyInstaller
    end

    def process(gem)
      begin
        destination = File.writable?(Gem.dir) ? Gem.dir : Gem.user_dir
        installer = Gem::DependencyInstaller.new :install_dir => destination
        installer.install gem
      rescue Errno::EACCES
        raise CommandError, "Insufficient permissions to install `#{text.green gem}`."
      rescue Gem::GemNotFoundException
        raise CommandError, "Gem `#{text.green gem}` not found."
      else
        Gem.refresh
        output.puts "Gem `#{text.green gem}` installed."
        require gem
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::GemInstall)
end
