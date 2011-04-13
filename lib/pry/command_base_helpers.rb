class Pry
  class CommandBase
    module CommandBaseHelpers

      private
      
      def gem_installed?(gem_name)
        require 'rubygems'
        !!Gem.source_index.find_name(gem_name).first
      end

      def command_dependencies_met?(options)
        return true if !options[:requires_gem]
        Array(options[:requires_gem]).all? do |g|
          gem_installed?(g)
        end
      end

      def stub_proc(name, options)
        gems_needed = Array(options[:requires_gem])
        gems_not_installed = gems_needed.select { |g| !gem_installed?(g) }
        proc do
          output.puts "\n`#{name}` requires the following gems to be installed: `#{gems_needed.join(", ")}`"
          output.puts "Command not available due to dependency on gems: `#{gems_not_installed.join(", ")}` not being met."
          output.puts "Type `install #{name}` to install the required gems and activate this command."
        end
      end

      def create_command_stub(names, description, options, block)
        Array(names).each do |name|
          commands[name] = {
            :description => "Not available. Execute `#{name}` command for more information.",
            :action => stub_proc(name, options),
            :stub_info => options
          }
        end
      end

    end
  end
end

      
