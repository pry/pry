class Pry
  module DefaultCommands
    Help = Pry::CommandSet.new do
      create_command "help" do |cmd|
        description "Show a list of commands, or help for one command"

        banner <<-BANNER
          Usage: help [ COMMAND ]

          With no arguments, help lists all the available commands in the current
          command-set along with their description.

          When given a command name as an argument, shows the help for that command.
        BANNER

        # Get a hash of available commands grouped by the "group" name.
        def grouped_commands
          commands.values.group_by(&:group)
        end

        def process
          if args.empty?
            display_index
          else
            display_topic(args.first)
          end
        end

        # Display the index view, with headings and short descriptions per command.
        #
        # @param Hash[String => Array[Commands]]
        def display_index(groups=grouped_commands)
          help_text = []

          groups.keys.sort.each do |key|

            commands = groups[key].select do |command|
              command.description && !command.description.empty?
            end.sort_by do |command|
              command.options[:listing].to_s
            end

            unless commands.empty?
              help_text << "\n#{text.bold(key)}"
              help_text += commands.map do |command|
                "  #{command.options[:listing].to_s.ljust(18)} #{command.description}"
              end
            end
          end

          stagger_output(help_text.join("\n"))
        end

        # Display help for an individual command or group.
        #
        # @param String  The string to search for.
        def display_topic(search)
          if command = command_set.find_command_for_help(search)
            stagger_output command.new.help
          else
            filtered = grouped_commands.select{ |key, value| normalize(key).start_with?(normalize(search)) }

            if filtered.empty?
              raise CommandError, "No help found for '#{args.first}'"
            elsif filtered.size == 1
              display_index(filtered.first.first => filtered.first.last)
            else
              names = filtered.map(&:first)
              last = names.pop
              output.puts "Did you mean: #{names.join(", ")} or #{last}?"
            end
          end
        end

        # Clean search terms to make it easier to search group names
        #
        # @param String
        # @return String
        def normalize(key)
          key.downcase.gsub(/pry\W+/, '')
        end
      end
    end
  end
end
