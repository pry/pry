class Pry
  module DefaultCommands

    Gems = Pry::CommandSet.new do

      command "gem-install", "Install a gem and refresh the gem cache." do |gem|
        if gem
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
        else
          output.puts "gem-install requires the name of a gem as an argument."
        end
      end

      command "gem-cd", "Change working directory to specified gem's directory." do |gem|
        if gem
          spec = Gem.source_index.find_name(gem).first
          spec ? Dir.chdir(spec.full_gem_path) : output.puts("Gem `#{gem}` not found.")
        else
          output.puts 'gem-cd requires the name of a gem as an argument.'
        end
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

      command "req", "Requires gem(s). No need for quotes! (If the gem isn't installed, it will ask if you want to install it.)" do |*gems|
        gems = gems.join(' ').gsub(',', '').split(/\s+/)
        gems.each do |gem|
          begin
            if require gem
              output.puts "#{text.bright_yellow(gem)} loaded"
            else
              output.puts "#{text.bright_white(gem)} already loaded"
            end

          rescue LoadError => e

            if gem_installed? gem
              output.puts e.inspect
            else
              output.puts "#{text.bright_red(gem)} not found"
              if prompt("Install the gem?") == "y"
                run "gem-install", gem
              end
            end

          end # rescue
        end # gems.each
      end

    end
  end
end
