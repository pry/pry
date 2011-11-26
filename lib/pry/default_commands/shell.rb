class Pry
  module DefaultCommands

    Shell = Pry::CommandSet.new do

      command(/\.(.*)/, "All text following a '.' is forwarded to the shell.", :listing => ".<shell command>", :use_prefix => false) do |cmd|
        if cmd =~ /^cd\s+(.+)/i
          dest = $1
          begin
            Dir.chdir File.expand_path(dest)
          rescue Errno::ENOENT
            raise CommandError, "No such directory: #{dest}"
          end
        else
          Pry.config.system.call(output, cmd, _pry_)
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

      alias_command "file-mode", "shell-mode"

      command "cat", "Show code from a file or Pry's input buffer. Type `cat --help` for more information." do |*args|
        start_line = 0
        end_line = -1
        file_name = nil
        bt_index = 0

        opts = Slop.parse!(args) do |opt|
          opt.on :s, :start, "Start line (defaults to start of file)Line 1 is the first line.", true, :as => Integer do |line|
            start_line = line - 1
          end

          opt.on :e, :end, "End line (defaults to end of file). Line -1 is the last line", true, :as => Integer do |line|
            end_line = line - 1
          end

          opt.on :ex, "Show a window of N lines either side of the last exception (defaults to 5).", :optional => true, :as => Integer do |bt_index_arg|
            window_size = Pry.config.exception_window_size || 5
            ex = _pry_.last_exception
            next if !ex
            if bt_index_arg
              bt_index = bt_index_arg
            else
              bt_index = ex.bt_index
            end
            ex.bt_index = (bt_index + 1) % ex.backtrace.size

            ex_file, ex_line = ex.bt_source_location_for(bt_index)
            start_line = (ex_line - 1) - window_size
            start_line = start_line < 0 ? 0 : start_line
            end_line = (ex_line - 1) + window_size
            if ex_file && RbxPath.is_core_path?(ex_file)
              file_name = RbxPath.convert_path_to_full(ex_file)
            else
              file_name = ex_file
            end
          end

          opt.on :i, :in, "Show entries from Pry's input expression history. Takes an index or range.", :optional => true, :as => Range, :default => -5..-1

          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :t, :type, "The specific file type for syntax higlighting (e.g ruby, python)", true, :as => Symbol
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.present?(:help)

        if opts.present?(:ex)
          if file_name.nil?
            raise CommandError, "No Exception or Exception has no associated file."
          end
        else
          file_name = args.shift
        end

        if opts.present?(:in)
          normalized_range = absolute_index_range(opts[:i], _pry_.input_array.length)
          input_items = _pry_.input_array[normalized_range] || []

          zipped_items = normalized_range.zip(input_items).reject { |_, s| s.nil? || s == "" }

          unless zipped_items.length > 0
            raise CommandError, "No expressions found."
          end

          if opts[:i].is_a?(Range)
            contents = ""

            zipped_items.each do |i, s|
              contents << "#{text.bold(i.to_s)}:\n"

              code = syntax_highlight_by_file_type_or_specified(s, nil, :ruby)

              if opts.present?(:'line-numbers')
                contents << text.indent(text.with_line_numbers(code, 1), 2)
              else
                contents << text.indent(code, 2)
              end
            end
          else
            contents = syntax_highlight_by_file_type_or_specified(zipped_items.first.last, nil, :ruby)
          end
        else
          unless file_name
            raise CommandError, "Must provide a file name."
          end

          begin
            contents, _, _ = read_between_the_lines(file_name, start_line, end_line)
          rescue Errno::ENOENT
            raise CommandError, "Could not find file: #{file_name}"
          end

          contents = syntax_highlight_by_file_type_or_specified(contents, file_name, opts[:type])

          if opts.present?(:'line-numbers')
            contents = text.with_line_numbers contents, start_line + 1
          end
        end

        # add the arrow pointing to line that caused the exception
        if opts.present?(:ex)
          ex_file, ex_line = _pry_.last_exception.bt_source_location_for(bt_index)
          contents = text.with_line_numbers contents, start_line + 1, :bright_red

          contents = contents.lines.each_with_index.map do |line, idx|
            l = idx + start_line
            if l == (ex_line - 1)
              " =>#{line}"
            else
              "   #{line}"
            end
          end.join

          # header for exceptions
          output.puts "\n#{Pry::Helpers::Text.bold('Exception:')} #{_pry_.last_exception.class}: #{_pry_.last_exception.message}\n--"
          output.puts "#{Pry::Helpers::Text.bold('From:')} #{ex_file} @ line #{ex_line} @ #{text.bold('level: ')} #{bt_index} of backtrace (of #{_pry_.last_exception.backtrace.size - 1}).\n\n"
        end

        set_file_and_dir_locals(file_name)

        if opts.present?(:flood)
          output.puts contents
        else
          stagger_output(contents)
        end
      end
    end

  end
end

