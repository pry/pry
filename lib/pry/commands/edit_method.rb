class Pry
  class Command::EditMethod < Pry::ClassCommand
    match 'edit-method'
    group 'Editing'
    description 'Edit the source code for a method.'

    banner <<-BANNER
      Usage: edit-method [OPTIONS] [METH]

      Edit the method METH in an editor.
      Ensure Pry.config.editor is set to your editor of choice.

      e.g: `edit-method hello_method`
      e.g: `edit-method Pry#rep`
      e.g: `edit-method`

      https://github.com/pry/pry/wiki/Editor-integration#wiki-Edit_method
    BANNER

    command_options :shellwords => false

    def options(opt)
      method_options(opt)
      opt.on :n, "no-reload", "Do not automatically reload the method's file after editing."
      opt.on "no-jump", "Do not fast forward editor to first line of method."
      opt.on :p, :patch, "Instead of editing the method's file, try to edit in a tempfile and apply as a monkey patch."
    end

    def process
      if !Pry.config.editor
        raise CommandError, "No editor set!\nEnsure that #{text.bold("Pry.config.editor")} is set to your editor of choice."
      end

      begin
        @method = method_object
      rescue MethodNotFound => err
      end

      if opts.present?(:patch) || (@method && @method.dynamically_defined?)
        if err
          raise err # can't patch a non-method
        end

        process_patch
      else
        if err && !File.exist?(target.eval('__FILE__'))
          raise err # can't edit a non-file
        end

        process_file
      end
    end

    def process_patch
      lines = @method.source.lines.to_a

      lines[0] = definition_line_for_owner(lines[0])

      temp_file do |f|
        f.puts lines
        f.flush
        f.close(false)
        invoke_editor(f.path, 0, true)

        source = wrap_for_nesting(wrap_for_owner(File.read(f.path)))

        if @method.alias?
          with_method_transaction(original_name, @method.owner) do
            _pry_.evaluate_ruby source
            Pry.binding_for(@method.owner).eval("alias #{@method.name} #{original_name}")
          end
        else
          _pry_.evaluate_ruby source
        end
      end
    end

    def process_file
      file, line = extract_file_and_line

      reload = !opts.present?(:'no-reload') && !Pry.config.disable_auto_reload
      invoke_editor(file, opts["no-jump"] ? 0 : line, reload)
      silence_warnings do
        load file if reload
      end
    end

    protected
      def extract_file_and_line
        if @method
          if @method.source_type == :c
            raise CommandError, "Can't edit a C method."
          else
            [@method.source_file, @method.source_line]
          end
        else
          [target.eval('__FILE__'), target.eval('__LINE__')]
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

      # The original name of the method, if it's not present raise an error telling
      # the user why we don't work.
      #
      def original_name
        @method.original_name or raise CommandError, "Pry can only patch methods created with the `def` keyword."
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
      def definition_line_for_owner(line)
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
      def wrap_for_owner(source)
        Thread.current[:__pry_owner__] = @method.owner
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
      def wrap_for_nesting(source)
        nesting = Pry::Code.from_file(@method.source_file).nesting_at(@method.source_line)

        (nesting + [source] + nesting.map{ "end" } + [""]).join("\n")
      rescue Pry::Indent::UnparseableNestingError => e
        source
      end
  end

  Pry::Commands.add_command(Pry::Command::EditMethod)
end
