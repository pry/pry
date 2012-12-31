class Pry
  # Uses the following state variables:
  #   - dynamical_ex_file [Array<String>]
  #       Utilised in `edit --ex --patch` operations. Contains the source code
  #       of a monkey patched file, in which an exception was raised. We store
  #       the entire source code because an exception may happen anywhere in the
  #       code and there is no way to predict that. So we simply superimpose
  #       everything (admittedly, doing extra job).
  class Command::Edit < Pry::ClassCommand
    require 'pry/commands/edit/method_patcher'
    require 'pry/commands/edit/exception_patcher'

    match 'edit'
    group 'Editing'
    description 'Invoke the default editor on a file.'

    banner <<-BANNER
      Usage: edit [--no-reload|--reload|--patch] [--line LINE] [--temp|--ex|FILE[:LINE]|OBJECT|--in N]

      Open a text editor. When no FILE is given, edits the pry input buffer.
      Ensure Pry.config.editor is set to your editor of choice.

      e.g: `edit sample.rb`
      e.g: `edit sample.rb --line 105`
      e.g: `edit MyClass#my_method`
      e.g: `edit -p MyClass#my_method`
      e.g: `edit YourClass`
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
      opt.on :p, :patch, "Instead of editing the object's file, try to edit in a tempfile and apply as a monkey patch."
    end

    def complete(search)
      super + Bond::Rc.files(search.split(" ").last || '')
    end

    def bad_option_combination?
      [opts.present?(:ex), opts.present?(:temp),
       opts.present?(:in), !args.empty?].count(true) > 1
    end

    def process
      if bad_option_combination?
        raise CommandError, "Only one of --ex, --temp, --in and FILE may be specified."
      end

      if local_edit?
        # edit of local code, eval'd within pry.
        process_local_edit
      elsif runtime_patch?
        # patch code without persisting changes
        apply_runtime_patch
      else
        # edit of remote code, eval'd at top-level
        process_remote_edit
      end
    end

    def process_local_edit
      content = Pry::Editor.edit_tempfile_with_content(initial_temp_file_content,
                                                       initial_temp_file_content.lines.count)
      if local_reload?
        silence_warnings do
          eval_string.replace content
        end
      end
    end

    def apply_runtime_patch
      if patch_exception?
        ExceptionPatcher.new(self).perform_patch
      else
        if code_object.is_a?(Pry::Method)
          MethodPatcher.new(self).perform_patch
        else
          raise NotImplementedError, "Cannot yet patch #{code_object} objects!"
        end
      end
    end

    def process_remote_edit
      file_name, line = retrieve_file_and_line
      raise CommandError, "#{file_name} is not a valid file name, cannot edit!" if not_a_real_file?(file_name)

      # Sanitize blanks.
      sanitized_file_name = Shellwords.escape(file_name)

      Pry::Editor.invoke_editor(sanitized_file_name, line, reload?(file_name))
      set_file_and_dir_locals(sanitized_file_name)

      if reload?(file_name)
        silence_warnings do
          TOPLEVEL_BINDING.eval(File.read(file_name), file_name)
        end
      end
    end

    def code_object
      @code_object ||= args.first && !probably_a_file?(args.first) &&
        Pry::CodeObject.lookup(args.first, target, _pry_)
    end

    def local_edit?
      !opts.present?(:ex) && !opts.present?(:current) && args.empty?
    end

    def runtime_patch?
      opts.present?(:patch) || dynamically_defined_method?
    end

    def dynamically_defined_method?
      code_object.is_a?(Pry::Method) &&
        code_object.dynamically_defined?
    end

    def patch_exception?
      opts.present?(:ex) && opts.present?(:patch)
    end

    def input_expression
      case opts[:i]
      when Range
        (_pry_.input_array[opts[:i]] || []).join
      when Fixnum
        _pry_.input_array[opts[:i]] || ""
      else
        raise Pry::CommandError, "Not a valid range: #{opts[:i]}"
      end
    end

    def reloadable?
      opts.present?(:reload) || opts.present?(:ex)
    end

    def never_reload?
      opts.present?(:'no-reload') || Pry.config.disable_auto_reload
    end

    # conditions much less strict than for reload? (which is for remote reloads)
    def local_reload?
      !never_reload?
    end

    def reload?(file_name="")
      (reloadable? || file_name.end_with?(".rb")) && !never_reload?
    end

    def initial_temp_file_content
      case
      when opts.present?(:temp)
        ""
      when opts.present?(:in)
        input_expression
      when eval_string.strip != ""
        eval_string
      else
        _pry_.input_array.reverse_each.find { |x| x && x.strip != "" } || ""
      end
    end

    def probably_a_file?(str)
      [".rb", ".c", ".py", ".yml", ".gemspec"].include? File.extname(str) ||
        str =~ /\/|\\/
    end

    def retrieve_file_and_line
      file_name, line = if opts.present?(:ex)
                          file_and_line_for_exception
                        elsif opts.present?(:current)
                          current_file_and_line
                        else
                          object_file_and_line
                        end

      [file_name, opts.present?(:line) ? opts[:l].to_i : line]
    end

    def file_and_line_for_exception
      raise CommandError, "No exception found." if _pry_.last_exception.nil?

      file_name, line = _pry_.last_exception.bt_source_location_for(opts[:ex].to_i)
      raise CommandError, "Exception has no associated file." if file_name.nil?
      raise CommandError, "Cannot edit exceptions raised in REPL." if Pry.eval_path == file_name

      file_name = RbxPath.convert_path_to_full(file_name) if RbxPath.is_core_path?(file_name)

      [file_name, line]
    end

    def current_file_and_line
      [target.eval("__FILE__"), target.eval("__LINE__")]
    end

    def object_file_and_line
      if code_object
        [code_object.source_file, code_object.source_line]
      else
        # break up into file:line
        file_name = File.expand_path(args.first)
        line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
        [file_name, line]
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::Edit)
end
