class Pry
  module DefaultCommands

    Shell = Pry::CommandSet.new do

      command(/\.(.*)/, "All text following a '.' is forwarded to the shell.", :listing => ".<shell command>") do |cmd|
        if cmd =~ /^cd\s+(.+)/i
          dest = $1
          begin
            Dir.chdir File.expand_path(dest)
          rescue Errno::ENOENT
            output.puts "No such directory: #{dest}"
          end

        else
          if !system(cmd)
            output.puts "Error: there was a problem executing system command: #{cmd}"
          end
        end
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
        start_line = 0
        end_line = -1

        opts = Slop.parse!(args) do |opt|
          opt.on :s, :start, "Start line (defaults to start of file)Line 1 is the first line.", true, :as => Integer do |line|
            start_line = line - 1
          end

          opt.on :e, :end, "End line (defaults to end of file). Line -1 is the last line", true, :as => Integer do |line|
            end_line = line - 1
          end

          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :t, :type, "The specific file type for syntax higlighting (e.g ruby, python)", true, :as => Symbol
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        file_name = args.shift
        if !file_name
          output.puts "Must provide a file name."
          next
        end

        contents, normalized_start_line, _ = read_between_the_lines(file_name, start_line, end_line)

        if Pry.color
          contents = syntax_highlight_by_file_type_or_specified(contents, file_name, opts[:type])
        end

        set_file_and_dir_locals(file_name)
        render_output(opts.flood?, opts.l? ? normalized_start_line + 1 : false, contents)
        contents
      end
    end

  end
end

