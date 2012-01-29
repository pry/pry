class Pry
  module DefaultCommands

    Gems = Pry::CommandSet.new do

      create_command "gem-install", "Install a gem and refresh the gem cache.", :argument_required => true do |gem|

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
          end
        end
      end

      create_command "gem-cd", "Change working directory to specified gem's directory.", :argument_required => true do |gem|
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

      create_command "gem-list", "List and search installed gems." do |pattern|
        banner <<-BANNER
          Usage: gem-list [REGEX]

          List all installed gems, when a regex is provided, limit the output to those that
          match the regex.
        BANNER

        def process(pattern=nil)
          pattern = Regexp.compile(pattern || '')
          gems    = if Gem::Specification.respond_to?(:each)
                      Gem::Specification.select{|spec| spec.name =~ pattern }.group_by(&:name)
                    else
                      Gem.source_index.gems.values.group_by(&:name).select { |gemname, specs| gemname =~ pattern }
                    end

          gems.each do |gem, specs|
            specs.sort! do |a,b|
              Gem::Version.new(b.version) <=> Gem::Version.new(a.version)
            end

            versions = specs.each_with_index.map do |spec, index|
              index == 0 ? text.bright_green(spec.version.to_s) : text.green(spec.version.to_s)
            end

            output.puts "#{text.default gem} (#{versions.join ', '})"
          end
        end
      end
    end
  end
end
