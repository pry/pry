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

      def bold(text)
        Pry.color ? "\e[1m#{text}\e[0m" : text
      end

      # formatting
      def heading(text)
        text = "#{text}\n--"
        Pry.color ? "\e[1m#{text}\e[0m": text
      end

      def page_size
        27
      end
      
      # a simple pager for systems without `less`. A la windows.
      def simple_pager(text)
        text_array = text.lines.to_a
        text_array.each_slice(page_size) do |chunk|
          output.puts chunk.join
          break if chunk.size < page_size
          if text_array.size > page_size
            output.puts "\n<page break> --- Press enter to continue ( q<enter> to break ) --- <page break>" 
            break if $stdin.gets.chomp == "q"
          end
        end
      end
      
      # Try to use `less` for paging, if it fails then use
      # simple_pager. Also do not page if Pry.pager is falsey
      def stagger_output(text)
        if text.lines.count < page_size || !Pry.pager
          output.puts text
          return
        end
        lesspipe { |less| less.puts text }
      rescue Exception
        simple_pager(text)
      end

      # thanks to epitron for this method
      def lesspipe(*args)
        if args.any? and args.last.is_a?(Hash)
          options = args.pop
        else
          options = {}
        end
        
        output = args.first if args.any?
        
        params = []
        params << "-R" unless options[:color] == false
        params << "-S" unless options[:wrap] == true
        params << "-F" unless options[:always] == true
        if options[:tail] == true
          params << "+\\>"
          $stderr.puts "Seeking to end of stream..."
        end
        params << "-X"
        
        IO.popen("less #{params * ' '}", "w") do |less|
          if output
            less.puts output
          else
            yield less
          end
        end
      end      

    end
  end
end

      
