class Pry
  class Command::InstallCommand < Pry::ClassCommand
    match 'install-command'
    group 'Commands'
    description 'Install a disabled command.'

    banner <<-'BANNER'
      Usage: install-command COMMAND

      Installs the gems necessary to run the given COMMAND. You will generally not
      need to run this unless told to by an error message.
    BANNER

    def process(name)
      require 'rubygems/dependency_installer' unless defined? Gem::DependencyInstaller
      command = find_command(name)

      if command_dependencies_met?(command.options)
        output.puts "Dependencies for #{command.name} are met. Nothing to do."
        return
      end

      output.puts "Attempting to install `#{name}` command..."
      gems_to_install = Array(command.options[:requires_gem])

      gems_to_install.each do |g|
        next if Rubygem.installed?(g)
        output.puts "Installing `#{g}` gem..."

        begin
          Gem::DependencyInstaller.new.install(g)
        rescue Gem::GemNotFoundException
          raise CommandError, "Required Gem: `#{g}` not found. Aborting command installation."
        end
      end

      Gem.refresh
      gems_to_install.each do |g|
        begin
          require g
        rescue LoadError
          raise CommandError, "Required Gem: `#{g}` installed but not found?!. Aborting command installation."
        end
      end

      output.puts "Installation of `#{name}` successful! Type `help #{name}` for information"
    end
  end

  Pry::Commands.add_command(Pry::Command::InstallCommand)
end
