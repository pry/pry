class Pry
  # Uses the following state variables:
  #   - dynamical_ex_file [Array<String>]
  #       Utilised in `edit --ex --patch` operations. Contains the source code
  #       of a monkey patched file, in which an exception was raised. We store
  #       the entire source code because an exception may happen anywhere in the
  #       code and there is no way to predict that. So we simply superimpose
  #       everything (admittedly, doing extra job).
  class Command::Edit < Pry::ClassCommand
    match 'edit'
    group 'Editing'
    description 'Invoke the default editor on a file.'

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

    def bad_option_combination?
      [opts.present?(:ex), opts.present?(:temp),
       opts.present?(:in), !args.empty?].count(true) > 1
    end

    def local_edit?
      !opts.present?(:ex) && !opts.present?(:current) && args.empty?
    end

    def process
      if bad_option_combination?
        raise CommandError, "Only one of --ex, --temp, --in and FILE may be specified."
      end

      if local_edit?
        # edit of local code, eval'd within pry.
        process_local_edit
      elsif runtime_patch?
        # patch an exception
        apply_runtime_patch
      else
        # edit of remote code, eval'd at top-level
        process_remote_edit
      end
    end

    def retrieve_code_object
      !probably_a_file?(args.first) && Pry::CodeObject.lookup(args.first, target, _pry_)
    end

    def runtime_patch?
      opts.present?(:patch)
    end

    def retrieve_input_expression
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
        retrieve_input_expression
      when eval_string.strip != ""
        eval_string
      else
        _pry_.input_array.reverse_each.find{ |x| x && x.strip != "" } || ""
      end
    end

    def process_local_edit
      content = initial_temp_file_content

      if local_reload?
        silence_warnings do
          eval_string.replace Pry::Editor.edit_tempfile_with_content(content, content.lines.count)
        end
      end
    end

    def probably_a_file?(str)
      [".rb", ".c", ".py", ".yml", ".gemspec"].include? File.extname(str) ||
        str =~ /\/|\\/
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
      if code_object = retrieve_code_object
        [code_object.source_file, code_object.source_line]
      else
        # break up into file:line
        file_name = File.expand_path(args.first)
        line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
        [file_name, line]
      end
    end

    def retrieve_file_and_line
      file_name, line = if opts.present?(:ex)
                          file_and_line_for_exception
                        elsif opts.present?(:current)
                          current_file_and_line
                        else
                          object_file_and_line
                        end

      if not_a_real_file?(file_name)
        raise CommandError, "#{file_name} is not a valid file name, cannot edit!"
      end

      [file_name, opts.present?(:line) ? opts[:l].to_i : line]
    end

    def patch_exception?
      opts.present?(:ex) && opts.present?(:patch)
    end

    def apply_runtime_patch_to_exception
      file_name, line = file_and_line_for_exception
      lines = state.dynamical_ex_file || File.read(file_name)

      source = Pry::Editor.edit_tempfile_with_content(lines)
      _pry_.evaluate_ruby source
      state.dynamical_ex_file = source.split("\n")
    end

    def apply_runtime_patch_to_method(method_object)
      lines = method_object.source.lines.to_a
      lines[0] = definition_line_for_owner(lines[0], method_object.original_name)

      source = wrap_for_nesting(wrap_for_owner(Pry::Editor.edit_tempfile_with_content(lines), method_object.owner), method_object)

      if method_object.alias?
        with_method_transaction(method_object.original_name, method_object.owner) do
          _pry_.evaluate_ruby source
          Pry.binding_for(method_object.owner).eval("alias #{method_object.name} #{original_name}")
        end
      else
        _pry_.evaluate_ruby source
      end
    end

    def apply_runtime_patch
      if patch_exception?
        apply_runtime_patch_to_exception
      else
        code_object = retrieve_code_object
        if code_object.is_a?(Pry::Method)
          apply_runtime_patch_to_method(code_object)
        else
          raise NotImplementedError, "Cannot yet patch #{code_object} objects!"
        end
      end
    end

    def process_remote_edit
      file_name, line = retrieve_file_and_line

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


    # Run some code ensuring that at the end target#meth_name will not have changed.
    #
    # When we're redefining aliased methods we will overwrite the method at the
    # unaliased name (so that super continues to work). By wrapping that code in a
    # transation we make that not happen, which means that alias_method_chains, etc.
    # continue to work.
    #
    # @param [String] meth_name  The method name before aliasing
    # @param [Module] target  The owner of the method
    def with_method_transaction(meth_name, target)
      target = Pry.binding_for(target)
      temp_name = "__pry_#{meth_name}__"

      target.eval("alias #{temp_name} #{meth_name}")
      yield
      target.eval("alias #{meth_name} #{temp_name}")
    ensure
      target.eval("undef #{temp_name}") rescue nil
    end

    # Update the definition line so that it can be eval'd directly on the Method's
    # owner instead of from the original context.
    #
    # In particular this takes `def self.foo` and turns it into `def foo` so that we
    # don't end up creating the method on the singleton class of the singleton class
    # by accident.
    #
    # This is necessarily done by String manipulation because we can't find out what
    # syntax is needed for the argument list by ruby-level introspection.
    #
    # @param String   The original definition line. e.g. def self.foo(bar, baz=1)
    # @return String  The new definition line. e.g. def foo(bar, baz=1)
    def definition_line_for_owner(line, original_name)
      if line =~ /^def (?:.*?\.)?#{Regexp.escape(original_name)}(?=[\(\s;]|$)/
        "def #{original_name}#{$'}"
      else
        raise CommandError, "Could not find original `def #{original_name}` line to patch."
      end
    end

    # Update the source code so that when it has the right owner when eval'd.
    #
    # This (combined with definition_line_for_owner) is backup for the case that
    # wrap_for_nesting fails, to ensure that the method will stil be defined in
    # the correct place.
    #
    # @param [String] source  The source to wrap
    # @return [String]
    def wrap_for_owner(source, owner)
      Thread.current[:__pry_owner__] = owner
      source = "Thread.current[:__pry_owner__].class_eval do\n#{source}\nend"
    end

    # Update the new source code to have the correct Module.nesting.
    #
    # This method uses syntactic analysis of the original source file to determine
    # the new nesting, so that we can tell the difference between:
    #
    #   class A; def self.b; end; end
    #   class << A; def b; end; end
    #
    # The resulting code should be evaluated in the TOPLEVEL_BINDING.
    #
    # @param [String] source  The source to wrap.
    # @return [String]
    def wrap_for_nesting(source, method_object)
      nesting = Pry::Code.from_file(method_object.source_file).nesting_at(method_object.source_line)

      (nesting + [source] + nesting.map{ "end" } + [""]).join("\n")
    rescue Pry::Indent::UnparseableNestingError => e
      source
    end

  end

  Pry::Commands.add_command(Pry::Command::Edit)
end
