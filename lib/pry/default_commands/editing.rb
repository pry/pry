require 'tempfile'
require 'pry/default_commands/hist'

class Pry
  module DefaultCommands

    Editing = Pry::CommandSet.new do
      import Hist

      create_command "!", "Clear the input buffer. Useful if the parsing process goes wrong and you get stuck in the read loop.", :use_prefix => false do
        def process
          output.puts "Input buffer cleared!"
          eval_string.replace("")
        end
      end

      create_command "show-input", "Show the contents of the input buffer for the current multi-line expression." do
        def process
          output.puts Code.new(eval_string).with_line_numbers
        end
      end

      create_command "edit" do
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
          opt.on :e, :ex, "Open the file that raised the most recent exception (_ex_.file)", :optional => true, :as => Integer
          opt.on :i, :in, "Open a temporary file containing the Nth line of _in_. N may be a range.", :optional => true, :as => Range, :default => -1..-1
          opt.on :t, :temp, "Open an empty temporary file"
          opt.on :l, :line, "Jump to this line in the opened file", true, :as => Integer
          opt.on :n, :"no-reload", "Don't automatically reload the edited code"
          opt.on :c, :"current", "Open the current __FILE__ and at __LINE__ (as returned by `whereami`)."
          opt.on :r, :reload, "Reload the edited code immediately (default for ruby files)"
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
            return output.puts "Not a valid range: #{opts[:i]}"
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
            invoke_editor(f.path, line)
            if !opts.present?(:'no-reload') && !Pry.config.disable_auto_reload
              silence_warnings do
                eval_string.replace(File.read(f.path))
              end
            end
          end
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

            # break up into file:line
            file_name = File.expand_path(args.first)
            line = file_name.sub!(/:(\d+)$/, "") ? $1.to_i : 1
          end

          if not_a_real_file?(file_name)
            raise CommandError, "#{file_name} is not a valid file name, cannot edit!"
          end

          line = opts[:l].to_i if opts.present?(:line)

          invoke_editor(file_name, line)
          set_file_and_dir_locals(file_name)

          if opts.present?(:reload) || ((opts.present?(:ex) || file_name.end_with?(".rb")) && !opts.present?(:'no-reload')) && !Pry.config.disable_auto_reload
            silence_warnings do
              TOPLEVEL_BINDING.eval(File.read(file_name), file_name)
            end
          end
        end
      end

      create_command "edit-method" do
        description "Edit the source code for a method."

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
          rescue NonMethodContextError => err
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

          if ((original_name = @method.original_name) &&
              lines[0] =~ /^def (?:.*?\.)?#{original_name}(?=[\(\s;]|$)/)
            lines[0] = "def #{original_name}#{$'}"
          else
            raise CommandError, "Pry can only patch methods created with the `def` keyword."
          end

          temp_file do |f|
            f.puts lines.join
            f.flush
            invoke_editor(f.path, 0)

            if @method.alias?
              with_method_transaction(original_name, @method.owner) do
                Pry.new(:input => StringIO.new(File.read(f.path))).rep(@method.owner)
                Pry.binding_for(@method.owner).eval("alias #{@method.name} #{original_name}")
              end
            else
              Pry.new(:input => StringIO.new(File.read(f.path))).rep(@method.owner)
            end
          end
        end

        def process_file
          file, line = extract_file_and_line

          invoke_editor(file, opts["no-jump"] ? 0 : line)
          silence_warnings do
            load file unless opts.present?(:'no-reload') || Pry.config.disable_auto_reload
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

          def with_method_transaction(meth_name, target=TOPLEVEL_BINDING)
            target = Pry.binding_for(target)
            temp_name = "__pry_#{meth_name}__"

            target.eval("alias #{temp_name} #{meth_name}")
            yield
            target.eval("alias #{meth_name} #{temp_name}")
          ensure
            target.eval("undef #{temp_name}") rescue nil
          end
      end

      create_command(/amend-line(?: (-?\d+)(?:\.\.(-?\d+))?)?/) do
        description "Amend a line of input in multi-line mode."
        command_options :interpolate => false, :listing => "amend-line"

        banner <<-'BANNER'
          Amend a line of input in multi-line mode. `amend-line N`, where the N in `amend-line N` represents line to replace.

          Can also specify a range of lines using `amend-line N..M` syntax. Passing '!' as replacement content deletes the line(s) instead.
          e.g amend-line 1 puts 'hello world! # replace line 1'
          e.g amend-line 1..4 !               # delete lines 1..4
          e.g amend-line 3 >puts 'goodbye'    # insert before line 3
          e.g amend-line puts 'hello again'   # no line number modifies immediately preceding line
        BANNER

        def process
          start_line_number, end_line_number, replacement_line = *args

          if eval_string.empty?
            raise CommandError, "No input to amend."
          end

          replacement_line = "" if !replacement_line
          input_array = eval_string.each_line.to_a

          end_line_number = start_line_number.to_i if !end_line_number
          line_range = start_line_number ? (one_index_number(start_line_number.to_i)..one_index_number(end_line_number.to_i))  : input_array.size - 1

          # delete selected lines if replacement line is '!'
          if arg_string == "!"
            input_array.slice!(line_range)
          elsif arg_string.start_with?(">")
            insert_slot = Array(line_range).first
            input_array.insert(insert_slot, arg_string[1..-1] + "\n")
          else
            input_array[line_range] = arg_string + "\n"
          end
          eval_string.replace input_array.join
          run "show-input"
        end
      end

      create_command "play" do
        description "Play back a string variable or a method or a file as input."

        banner <<-BANNER
          Usage: play [OPTIONS] [--help]

          The play command enables you to replay code from files and methods as
          if they were entered directly in the Pry REPL. Default action (no
          options) is to play the provided string variable

          e.g: `play -i 20 --lines 1..3`
          e.g: `play -m Pry#repl --lines 1..-1`
          e.g: `play -f Rakefile --lines 5`

          https://github.com/pry/pry/wiki/User-Input#wiki-Play
        BANNER

        attr_accessor :content

        def setup
          self.content   = ""
        end

        def options(opt)
          opt.on :m, :method, "Play a method's source.", true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            self.content << meth.source
          end
          opt.on :d, :doc, "Play a method's documentation.", true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            text.no_color do
              self.content << process_comment_markup(meth.doc, :ruby)
            end
          end
          opt.on :c, :command, "Play a command's source.", true do |command_name|
            command = find_command(command_name)
            block = Pry::Method.new(find_command(command_name).block)
            self.content << block.source
          end
          opt.on :f, :file, "Play a file.", true do |file|
            self.content << File.read(File.expand_path(file))
          end
          opt.on :l, :lines, "Only play a subset of lines.", :optional => true, :as => Range, :default => 1..-1
          opt.on :i, :in, "Play entries from Pry's input expression history. Takes an index or range.", :optional => true,
          :as => Range, :default => -5..-1 do |range|
            input_expressions = _pry_.input_array[range] || []
            Array(input_expressions).each { |v| self.content << v }
          end
          opt.on :o, "open", 'When used with the -m switch, it plays the entire method except the last line, leaving the method definition "open". `amend-line` can then be used to modify the method.'
        end

        def process
          perform_play
          run "show-input" unless _pry_.complete_expression?(eval_string)
        end

        def process_non_opt
          args.each do |arg|
            begin
              self.content << target.eval(arg)
            rescue Pry::RescuableException
              raise CommandError, "Prblem when evaling #{arg}."
            end
          end
        end

        def perform_play
          process_non_opt

          if opts.present?(:lines)
            self.content = restrict_to_lines(self.content, opts[:l])
          end

          if opts.present?(:open)
            self.content = restrict_to_lines(self.content, 1..-2)
          end

          eval_string << self.content
        end
      end
    end
  end
end
