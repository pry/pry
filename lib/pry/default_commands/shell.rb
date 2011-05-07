class Pry
  module DefaultCommands

    Shell = Pry::CommandSet.new do

      # this cannot be accessed, it's just for help purposes.
      command ".<shell command>", "All text following a '.' is forwarded to the shell." do
      end

      command "shell-mode", "Toggle shell mode. Bring in pwd prompt and file completion." do
        case Pry.active_instance.prompt
        when Pry::SHELL_PROMPT
          Pry.active_instance.pop_prompt
          Pry.active_instance.custom_completions = Pry::DEFAULT_CUSTOM_COMPLETIONS
        else
          Pry.active_instance.push_prompt Pry::SHELL_PROMPT
          Pry.active_instance.custom_completions = Pry::FILE_COMPLETIONS
          Readline.completion_proc = Pry::InputCompleter.build_completion_proc target,
          Pry.active_instance.instance_eval(&Pry::FILE_COMPLETIONS)
        end
      end

      alias_command "file-mode", "shell-mode", ""


      command "cat", "Show output of file FILE. Type `cat --help` for more information." do |*args|
        options= {}
        file_name = nil
        start_line = 0
        end_line = -1
        file_type = nil

        OptionParser.new do |opts|
          opts.banner = %{Usage: cat [OPTIONS] FILE
Cat a file. Defaults to displaying whole file. Syntax highlights file if type is recognized.
e.g: cat hello.rb
--
}
          opts.on("-l", "--line-numbers", "Show line numbers.") do |line|
            options[:l] = true
          end

          opts.on("-s", "--start LINE", "Start line (defaults to start of file). Line 1 is the first line.") do |line|
            start_line = line.to_i - 1
          end

          opts.on("-e", "--end LINE", "End line (defaults to end of file). Line -1 is the last line.") do |line|
            end_line = line.to_i - 1
          end

          opts.on("-t", "--type TYPE", "The specific file type for syntax higlighting (e.g ruby, python, cpp, java)") do |type|
            file_type = type.to_sym
          end

          opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
            options[:f] = true
          end

          opts.on_tail("-h", "--help", "This message.") do
            output.puts opts
            options[:h] = true
          end
        end.order(args) do |v|
          file_name = v
        end

        next if options[:h]

        if !file_name
          output.puts "Must provide a file name."
          next
        end

        contents, normalized_start_line, _ = read_between_the_lines(file_name, start_line, end_line)

        if Pry.color
          contents = syntax_highlight_by_file_type_or_specified(contents, file_name, file_type)
        end

        set_file_and_dir_locals(file_name)
        render_output(options[:f], options[:l] ? normalized_start_line + 1 : false, contents)
        contents
      end


    end

  end
end

