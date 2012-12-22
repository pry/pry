class Pry
  # Uses the following state variables:
  #   - dynamical_ex_file [Array<String>]
  #       Utilised in `edit --ex --patch` operations. Contains the source code
  #       of a monkey patched file, in which an exception was raised. We store
  #       the entire source code because an exception may happen anywhere in the
  #       code and there is no way to predict that. So we simply superimpose
  #       everything (admittedly, doing extra job).
  Pry::Commands.create_command "edit" do
    group 'Editing'
    description "Invoke the default editor on a file."

    banner <<-BANNER
      Usage: edit [--no-reload|--reload] [--line LINE] [--temp|--ex|FILE[:LINE]|--in N]

      Open a text editor. When no FILE is given, edits the pry input buffer.
      Ensure Pry.config.editor is set to your editor of choice.

      e.g: `edit sample.rb`
      e.g: `edit sample.rb --line 105`
      e.g: `edit --ex`

      https://github.com/pry/pry/wiki/Editor-integration#wiki-Edit_command
    BANNER

    def options(opt)
      opt.on :e, :ex, "Open the file that raised the most recent exception (_ex_.file)", :optional_argument => true, :as => Integer
      opt.on :i, :in, "Open a temporary file containing the Nth input expression. N may be a range.", :optional_argument => true, :as => Range, :default => -1..-1
      opt.on :t, :temp, "Open an empty temporary file"
      opt.on :l, :line, "Jump to this line in the opened file", :argument => true, :as => Integer
      opt.on :n, :"no-reload", "Don't automatically reload the edited code"
      opt.on :c, :current, "Open the current __FILE__ and at __LINE__ (as returned by `whereami`)."
      opt.on :r, :reload, "Reload the edited code immediately (default for ruby files)"
      opt.on :p, :patch, "Instead of opening the file that raised the exception, try to edit in a tempfile an apply as a monkey patch."
    end

    def complete(search)
      super + Bond::Rc.files(search.split(" ").last || '')
    end

    def process
      if [opts.present?(:ex), opts.present?(:temp), opts.present?(:in), !args.empty?].count(true) > 1
        raise CommandError, "Only one of --ex, --temp, --in and FILE may be specified."
      end

      if !opts.present?(:ex) && !opts.present?(:current) && args.empty?
        # edit of local code, eval'd within pry.
        process_local_edit
      else
        # edit of remote code, eval'd at top-level
        process_remote_edit
      end
    end

    def process_i
      case opts[:i]
      when Range
        (_pry_.input_array[opts[:i]] || []).join
      when Fixnum
        _pry_.input_array[opts[:i]] || ""
      else
        raise Pry::CommandError, "Not a valid range: #{opts[:i]}"
      end
    end

    def process_local_edit
      content = case
        when opts.present?(:temp)
          ""
        when opts.present?(:in)
          process_i
        when eval_string.strip != ""
          eval_string
        else
          _pry_.input_array.reverse_each.find{ |x| x && x.strip != "" } || ""
      end

      line = content.lines.count

      temp_file do |f|
        f.puts(content)
        f.flush
        reload = !opts.present?(:'no-reload') && !Pry.config.disable_auto_reload
        f.close(false)
        invoke_editor(f.path, line, reload)
        if reload
          silence_warnings do
            eval_string.replace(File.read(f.path))
          end
        end
      end
    end

    def probably_a_file?(str)
      [".rb", ".c", ".py", ".yml", ".gemspec"].include? File.extname(str) ||
      str =~ /\/|\\/
    end

    def process_remote_edit
      if opts.present?(:ex)
        if _pry_.last_exception.nil?
          raise CommandError, "No exception found."
        end

        ex = _pry_.last_exception
        bt_index = opts[:ex].to_i

        ex_file, ex_line = ex.bt_source_location_for(bt_index)
        if ex_file && RbxPath.is_core_path?(ex_file)
          file_name = RbxPath.convert_path_to_full(ex_file)
        else
          file_name = ex_file
        end

        line = ex_line

        if file_name.nil?
          raise CommandError, "Exception has no associated file."
        end

        if Pry.eval_path == file_name
          raise CommandError, "Cannot edit exceptions raised in REPL."
        end

      elsif opts.present?(:current)
        file_name = target.eval("__FILE__")
        line = target.eval("__LINE__")
      else

        if !probably_a_file?(args.first) && code_object = Pry::CodeObject.lookup(args.first, target, _pry_)
          file_name = code_object.source_file
          line = code_object.source_line
        else
          # break up into file:line
          file_name = File.expand_path(args.first)
          line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
        end
      end

      if not_a_real_file?(file_name)
        raise CommandError, "#{file_name} is not a valid file name, cannot edit!"
      end

      line = opts[:l].to_i if opts.present?(:line)

      reload = opts.present?(:reload) || ((opts.present?(:ex) || file_name.end_with?(".rb")) && !opts.present?(:'no-reload')) && !Pry.config.disable_auto_reload

      if opts.present?(:ex) && opts.present?(:patch)
        lines = state.dynamical_ex_file || File.open(ex_file).read

        temp_file do |f|
          f.puts lines
          f.flush
          f.close(false)

          tempfile_path = f.path
          invoke_editor(tempfile_path, line, reload)
          source = File.read(tempfile_path)
          _pry_.evaluate_ruby source

          state.dynamical_ex_file = source.split("\n")
        end
      else
        # Sanitize blanks.
        sanitized_file_name = Shellwords.escape(file_name)

        invoke_editor(sanitized_file_name, line, reload)
        set_file_and_dir_locals(sanitized_file_name)

        if reload
          silence_warnings do
            TOPLEVEL_BINDING.eval(File.read(file_name), file_name)
          end
        end
      end
    end
  end
end
