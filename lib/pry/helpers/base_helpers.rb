class Pry
  module Helpers

    module BaseHelpers
     module_function

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
          output.puts "\n#{name} requires the following gems to be installed: #{(gems_needed.join(", "))}"
          output.puts "Command not available due to dependency on gems: `#{gems_not_installed.join(", ")}` not being met."
          output.puts "Type `install #{name}` to install the required gems and activate this command."
        end
      end

      def create_command_stub(names, description, options, block)
        Array(names).each do |name|
          commands[name] = {
            :description => "Not available. Execute #{(name)} command for more information.",
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

      COLORS = {
         "black" => 0,
         "red" => 1,
         "green" => 2,
         "yellow" => 3,
         "blue" => 4,
         "purple" => 5,
         "magenta" => 5,
         "cyan" => 6,
         "white" => 7
      }

      COLORS.each do |color, i|
        define_method color do |str|
          Pry.color ? "\033[0;#{30+i}m#{str}\033[0m" : str
        end

        define_method "bright_#{color}" do |str|
          Pry.color ? "\033[1;#{30+i}m#{str}\033[0m" : str
        end
      end

      alias_method :grey, :bright_black
      alias_method :gray, :bright_black

      require 'set'
      VALID_COLORS = Set.new(
        COLORS.keys +
        COLORS.keys.map{|k| "bright_#{k}" } +
        ["grey", "gray"]
      )

      def bold(text)
        Pry.color ? "\e[1m#{text}\e[0m" : text
      end

      #
      # Colorize a string that has "color tags".
      #
      # Examples:
      #    puts colorize("<light_green><magenta>*</magenta> Hey mom! I am <light_blue>SO</light_blue> colored right now.</light_green>")
      #
      def colorize(string)
        stack = []

        # split the string into tags and literal strings
        tokens          = string.split(/(<\/?[\w\d_]+>)/)
        tokens.delete_if { |token| token.size == 0 }

        result        = ""

        tokens.each do |token|

          # token is an opening tag!

          if /<([\w\d_]+)>/ =~ token and VALID_COLORS.include?($1) #valid_tag?($1)
            stack.push $1

          # token is a closing tag!

          elsif /<\/([\w\d_]+)>/ =~ token and VALID_COLORS.include?($1) # valid_tag?($1)

            # if this color is on the stack somwehere...
            if pos = stack.rindex($1)
              # close the tag by removing it from the stack
              stack.delete_at pos
            else
              raise "Error: tried to close an unopened color tag -- #{token}"
            end

          # token is a literal string!

          else

            color = (stack.last || "white")
            #color = BBS_COLOR_TABLE[color.to_i] if color =~ /^\d+$/
            result << send(color, token) # colorize the result

          end

        end

        result
      end

      def highlight(string, regexp, highlight_color=:bright_yellow)
        highlighted = string.gsub(regexp) { |match| "<#{highlight_color}>#{match}</#{highlight_color}>" }
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
      # FIXME! Another JRuby hack
      def stagger_output(text)
        if text.lines.count < page_size || !Pry.pager
          output.puts text
          return
        end

        # FIXME! Another JRuby hack
        if Object.const_defined?(:RUBY_ENGINE) && RUBY_ENGINE =~ /jruby/
          simple_pager(text)
        else
          lesspipe { |less| less.puts text }
        end
      rescue Errno::ENOENT
        simple_pager(text)
      rescue Errno::EPIPE
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
