class Pry
  module DefaultCommands

    Shell = Pry::CommandSet.new do

      command(/\.(.*)/, "All text following a '.' is forwarded to the shell.", :listing => ".<shell command>", :use_prefix => false) do |cmd|
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
        case _pry_.prompt
        when Pry::SHELL_PROMPT
          _pry_.pop_prompt
          _pry_.custom_completions = Pry::DEFAULT_CUSTOM_COMPLETIONS
        else
          _pry_.push_prompt Pry::SHELL_PROMPT
          _pry_.custom_completions = Pry::FILE_COMPLETIONS
          Readline.completion_proc = Pry::InputCompleter.build_completion_proc target,
          _pry_.instance_eval(&Pry::FILE_COMPLETIONS)
        end
      end

      alias_command "file-mode", "shell-mode", ""

      command "cat", "Show output of file FILE. Type `cat --help` for more information." do |*args|
        start_line = 0
        end_line = -1
        file_name = nil
        last_exception = target.eval("_ex_")

        opts = Slop.parse!(args) do |opt|
          opt.on :s, :start, "Start line (defaults to start of file)Line 1 is the first line.", true, :as => Integer do |line|
            start_line = line - 1
          end

          opt.on :e, :end, "End line (defaults to end of file). Line -1 is the last line", true, :as => Integer do |line|
            end_line = line - 1
          end

          opt.on :ex, "Show a window of N lines either side of the last exception (defaults to 5).", :optional => true, :as => Integer do |window_size|
            window_size ||= 5
            ex = last_exception
            next if !ex
            start_line = (ex.line - 1) - window_size
            start_line = start_line < 0 ? 0 : start_line
            end_line = (ex.line - 1) + window_size
            file_name = ex.file
          end

          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :t, :type, "The specific file type for syntax higlighting (e.g ruby, python)", true, :as => Symbol
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        if opts.ex?
          next output.puts "No Exception or Exception has no associated file." if file_name.nil?
          next output.puts "Cannot cat exceptions raised in REPL." if Pry.eval_path == file_name
        else
          file_name = args.shift
        end

        if !file_name
          output.puts "Must provide a file name."
          next
        end

        contents, _, _ = read_between_the_lines(file_name, start_line, end_line)
        contents = syntax_highlight_by_file_type_or_specified(contents, file_name, opts[:type])

        if opts.l?
          contents = text.with_line_numbers contents, start_line + 1
        end

        # add the arrow pointing to line that caused the exception
        if opts.ex?
          contents = text.with_line_numbers contents, start_line + 1, :bright_red

          contents = contents.lines.each_with_index.map do |line, idx|
            l = idx + start_line
            if l == (last_exception.line - 1)
              " =>#{line}"
            else
              "   #{line}"
            end
          end.join

          # header for exceptions
          output.puts "\n#{Pry::Helpers::Text.bold('Exception:')}: #{last_exception.class}: #{last_exception.message}"
          output.puts "#{Pry::Helpers::Text.bold('From:')} #{file_name} @ line #{last_exception.line}\n\n"
        end

        set_file_and_dir_locals(file_name)

        if opts.f?
          output.puts contents
        else
          stagger_output(contents)
        end
      end
    end

  end
end

