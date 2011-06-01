class Pry
  module DefaultCommands

    Gems = Pry::CommandSet.new do

      command "gem-install", "Install a gem and refresh the gem cache.", :argument_required => true do |gem|
        begin
          destination = File.writable?(Gem.dir) ? Gem.dir : Gem.user_dir
          installer = Gem::DependencyInstaller.new :install_dir => destination
          installer.install gem
        rescue Errno::EACCES
          output.puts "Insufficient permissions to install `#{text.green gem}`"
        rescue Gem::GemNotFoundException
          output.puts "Gem `#{text.green gem}` not found."
        else
          Gem.refresh
          output.puts "Gem `#{text.green gem}` installed."
        end
      end

      command "gem-cd", "Change working directory to specified gem's directory.", :argument_required => true do |gem|
        specs = Gem::Specification.respond_to?(:each) ? Gem::Specification.find_all_by_name(gem) : Gem.source_index.find_name(gem)
        spec  = specs.sort { |a,b| Gem::Version.new(b.version) <=> Gem::Version.new(a.version) }.first
        spec ? Dir.chdir(spec.full_gem_path) : output.puts("Gem `#{gem}` not found.")
      end

      command "gem-list", "List/search installed gems. (Optional parameter: a regexp to limit the search)" do |pattern|
        pattern = Regexp.new pattern.to_s, Regexp::IGNORECASE
        gems    = if Gem::Specification.respond_to?(:each)
                    Gem::Specification.select{|spec| spec.name =~ pattern }.group_by(&:name)
                  else
                    Gem.source_index.gems.values.group_by(&:name).select { |gemname, specs| gemname =~ pattern }
                  end

        gems.each do |gem, specs|
          specs.sort! do |a,b| 
            Gem::Version.new(b.version) <=> Gem::Version.new(a.version) 
          end
          
          versions = specs.map.with_index do |spec, index|
            index == 0 ? text.bright_green(spec.version.to_s) : text.green(spec.version.to_s) 
          end

          output.puts "#{text.white gem} (#{versions.join ', '})"
        end
      end

    end
  end
end
