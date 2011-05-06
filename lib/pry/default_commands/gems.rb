class Pry
  module DefaultCommands

    Gems = Pry::CommandSet.new :gems do

      command "gem-install", "Install a gem and refresh the gem cache." do |gem_name|
        gem_home = Gem.instance_variable_get(:@gem_home)
        output.puts "Attempting to install gem: #{bold(gem_name)}"

        begin
          if File.writable?(gem_home)
            Gem::DependencyInstaller.new.install(gem_name)
            output.puts "Gem #{bold(gem_name)} successfully installed."
          else
            if system("sudo gem install #{gem_name}")
              output.puts "Gem #{bold(gem_name)} successfully installed."
            else
              output.puts "Gem #{bold(gem_name)} could not be installed."
              next
            end
          end
        rescue Gem::GemNotFoundException
          output.puts "Required Gem: #{bold(gem_name)} not found."
          next
        end

        Gem.refresh
        output.puts "Refreshed gem cache."
      end

      command "gem-cd", "Change working directory to specified gem's directory." do |gem_name|
        require 'rubygems'
        gem_spec = Gem.source_index.find_name(gem_name).first
        next output.puts("Gem `#{gem_name}` not found.") if !gem_spec
        Dir.chdir(File.expand_path(gem_spec.full_gem_path))
      end


      command "gem-list", "List/search installed gems. (Optional parameter: a regexp to limit the search)" do |arg|
        gems = Gem.source_index.gems.values.group_by(&:name)
        if arg
          query = Regexp.new(arg, Regexp::IGNORECASE)
          gems = gems.select { |gemname, specs| gemname =~ query }
        end

        gems.each do |gemname, specs|
          versions = specs.map(&:version).sort.reverse.map(&:to_s)
          versions = ["#{bright_green versions.first}"] + versions[1..-1].map{|v| "#{green v}" }

          gemname = highlight(gemname, query) if query
          output.puts "#{white gemname} (#{grey(versions.join ', ')})"
        end
      end

    end
  end
end
