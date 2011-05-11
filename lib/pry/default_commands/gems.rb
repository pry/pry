class Pry
  module DefaultCommands

    Gems = Pry::CommandSet.new do

      command "gem-install", "Install a gem and refresh the gem cache.", :arguments_required => 1 do |gem|
        if File.writable? Gem.dir
          installer = Gem::DependencyInstaller.new :install_dir => Gem.dir
          installer.install gem
          output.puts "Gem '#{text.green gem}' installed."
        elsif File.writable? Gem.user_dir 
          installer = Gem::DependencyInstaller.new :install_dir => Gem.user_dir
          installer.install gem
          output.puts "Gem '#{text.green gem}' installed to your user directory"
        else
          output.puts "Insufficient permissions to install `#{text.green gem}`"
        end

        Gem.refresh
      end

      command "gem-cd", "Change working directory to specified gem's directory.", :arguments_required => 1 do |gem|
        spec = Gem.source_index.find_name(gem).first
        spec ? Dir.chdir(spec.full_gem_path) : output.puts("Gem `#{gem}` not found.")
      end


      command "gem-list", "List/search installed gems. (Optional parameter: a regexp to limit the search)" do |pattern|
        pattern = Regexp.new pattern.to_s, Regexp::IGNORECASE
        gems = Gem.source_index.gems.values.group_by(&:name)

        gems.each do |gem, specs|
          if gem =~ pattern
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
end
