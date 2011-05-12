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
        spec = Gem.source_index.find_name(gem).first
        spec ? Dir.chdir(spec.full_gem_path) : output.puts("Gem `#{gem}` not found.")
      end


      command "gem-list", "List/search installed gems. (Optional parameter: a regexp to limit the search)" do |pattern|
        pattern = Regexp.new pattern.to_s, Regexp::IGNORECASE
        gems = Gem.source_index.find_name(pattern).group_by(&:name)

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
