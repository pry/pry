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

      #
      # Color helpers:
      #   gray, red, green, yellow, blue, purple, cyan, white,
      #   and bright_red, bright_green, etc...
      #
      # ANSI color codes:
      #   \033 => escape
      #     30 => color base
      #      1 => bright
      #      0 => normal
      #
      [ :gray, :red, :green, :yellow, :blue, :purple, :cyan, :white ].each_with_index do |color, i|
        define_method "bright_#{color}" do |str|
          Pry.color ? "\033[1;#{30+i}m#{str}\033[0m" : str
        end

        define_method color do |str|
          Pry.color ? "\033[0;#{30+i}m#{str}\033[0m" : str
        end
      end
      alias_method :magenta, :purple
      alias_method :bright_magenta, :bright_purple

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
      
      #
      # Create scrollable output via less!
      #
      # This command runs `less` in a subprocess, and gives you the IO to its STDIN pipe
      # so that you can communicate with it.
      #
      # Example:
      #
      #   lesspipe do |less|
      #     50.times { less.puts "Hi mom!" }
      #   end
      #
      # The default less parameters are:
      # * Allow colour
      # * Don't wrap lines longer than the screen
      # * Quit immediately (without paging) if there's less than one screen of text.
      # 
      # You can change these options by passing a hash to `lesspipe`, like so:
      #
      #   lesspipe(:wrap=>false) { |less| less.puts essay.to_s }
      #
      # It accepts the following boolean options:
      #    :color  => Allow ANSI colour codes?
      #    :wrap   => Wrap long lines?
      #    :always => Always page, even if there's less than one page of text?
      #
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


