class Pry
  module DefaultCommands
    Help = Pry::CommandSet.new do
      create_command "help" do |cmd|
        description "Show a list of commands. Type `help <foo>` for information about <foo>."

        banner <<-BANNER
          Usage: help [ COMMAND ]

          With no arguments, help lists all the available commands in the current
          command-set along with their description.

          When given a command name as an argument, shows the help for that command.
        BANNER

        # We only want to show commands that have descriptions, so that the
        # easter eggs don't show up.
        def visible_commands
          visible = {}
          commands.each do |key, command|
            visible[key] = command if command.description && !command.description.empty?
          end
          visible
        end

        # Get a hash of available commands grouped by the "group" name.
        def command_groups
          visible_commands.values.group_by(&:group)
        end

        def process
          if args.empty?
            display_index(command_groups)
          else
            display_search(args.first)
          end
        end

        # Display the index view, with headings and short descriptions per command.
        #
        # @param Hash[String => Array[Commands]]
        def display_index(groups)
          help_text = []

          groups.keys.sort_by(&method(:group_sort_key)).each do |key|
            commands = groups[key].sort_by{ |command| command.options[:listing].to_s }

            unless commands.empty?
              help_text << "#{text.bold(key)}\n" + commands.map do |command|
                "  #{command.options[:listing].to_s.ljust(18)} #{command.description}"
              end.join("\n")
            end
          end

          stagger_output(help_text.join("\n\n"))
        end

        # Display help for an individual command or group.
        #
        # @param String  The string to search for.
        def display_search(search)
          if command = command_set.find_command_for_help(search)
            display_command(command)
          else
            groups = search_hash(search, command_groups)

            if groups.size > 0
              display_index(groups)
              return
            end

            filtered = search_hash(search, visible_commands)
            raise CommandError, "No help found for '#{args.first}'" if filtered.empty?

            if filtered.size == 1
              display_command(filtered.values.first)
            else
              display_index({"'#{search}' commands" => filtered.values})
            end
          end
        end

        # Display help for an individual command.
        #
        # @param [Pry::Command]
        def display_command(command)
          stagger_output command.new.help
        end

        # Find a subset of a hash that matches the user's search term.
        #
        # If there's an exact match a Hash of one element will be returned,
        # otherwise a sub-Hash with every key that matches the search will
        # be returned.
        #
        # @param [String]  the search term
        # @param [Hash]  the hash to search
        def search_hash(search, hash)
          matching = {}

          hash.each_pair do |key, value|
            next unless key.is_a?(String)
            if normalize(key) == normalize(search)
              return {key => value}
            elsif normalize(key).start_with?(normalize(search))
              matching[key] = value
            end
          end

          matching
        end

        # Clean search terms to make it easier to search group names
        #
        # @param String
        # @return String
        def normalize(key)
          key.downcase.gsub(/pry\W+/, '')
        end

        def group_sort_key(group_name)
          [%w(Help Context Editing Introspection Input_and_output Navigating_pry Gems Basic Commands).index(group_name.gsub(' ', '_')) || 99, group_name]
        end
      end
    end
  end
end
