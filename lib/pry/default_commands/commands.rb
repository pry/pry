class Pry
  module DefaultCommands
    Commands = Pry::CommandSet.new do
      create_command "import-set", "Import a command set" do
        group "Commands"
        def process(command_set_name)
          raise CommandError, "Provide a command set name" if command_set.nil?

          set = target.eval(arg_string)
          _pry_.commands.import set
        end
      end

      create_command "install-command", "Install a disabled command." do |name|
        group 'Commands'

        banner <<-BANNER
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
            next if gem_installed?(g)
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
    end
  end
end

