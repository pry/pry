class Pry
  module DefaultCommands

    Documentation = Pry::CommandSet.new do

      create_command "ri", "View ri documentation. e.g `ri Array#each`" do
        banner <<-BANNER
          Usage: ri [spec]
          e.g. ri Array#each

          Relies on the ri executable being available. See also: show-doc.
        BANNER

        def process
          run ".ri", *args
        end
      end

      create_command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?", :shellwords => false do |*args|
        banner <<-BANNER
          Usage: show-doc [OPTIONS] [METH]
          Show the comments above method METH. Tries instance methods first and then methods by default.
          e.g show-doc hello_method
        BANNER

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          meth = method_object
          raise Pry::CommandError, "No documentation found." if meth.doc.nil? || meth.doc.empty?

          doc = process_comment_markup(meth.doc, meth.source_type)
          output.puts make_header(meth, doc)
          output.puts "#{text.bold("Owner:")} #{meth.owner || "N/A"}"
          output.puts "#{text.bold("Visibility:")} #{meth.visibility}"
          output.puts "#{text.bold("Signature:")} #{meth.signature}"
          output.puts

          if opts.present?(:b) || opts.present?(:l)
            doc = Code.new(doc, start_line, :text).
              with_line_numbers(true)
          end

          render_output(doc, opts)
        end

        def start_line
          if opts.present?(:'base-one')
             1
          else
            (method_object.source_line - method_object.doc.lines.count) || 1
          end
        end

      end

      alias_command "?", "show-doc"

      create_command "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info.", :shellwords => false do |*args|
        banner <<-BANNER
            Usage: stat [OPTIONS] [METH]
            Show method information for method METH and set _file_ and _dir_ locals.
            e.g: stat hello_method
        BANNER

        def options(opt)
          method_options(opt)
        end

        def process
          meth = method_object
          output.puts unindent <<-EOS
            Method Information:
            --
            Name: #{meth.name}
            Owner: #{meth.owner ? meth.owner : "Unknown"}
            Visibility: #{meth.visibility}
            Type: #{meth.is_a?(::Method) ? "Bound" : "Unbound"}
            Arity: #{meth.arity}
            Method Signature: #{meth.signature}
            Source Location: #{meth.source_location ? meth.source_location.join(":") : "Not found."}
          EOS
        end
      end

      create_command "gist", "Gist a method or expression history to github. Type `gist --help` for more info.", :requires_gem => "gist", :shellwords => false do
        banner <<-USAGE
          Usage: gist [OPTIONS] [METH]
          Gist method (doc or source) or input expression to github.
          Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
          e.g: gist -m my_method
          e.g: gist -d my_method
          e.g: gist -i 1..10
          e.g: gist -c show-method
          e.g: gist -m hello_world --lines 2..-2
        USAGE

        attr_accessor :content
        attr_accessor :code_type

        def setup
          require 'gist'
          self.content   = ""
          self.code_type = :ruby
        end

        def options(opt)
          opt.on :m, :method, "Gist a method's source.", true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            self.content << meth.source
            self.code_type = meth.source_type
          end
          opt.on :d, :doc, "Gist a method's documentation.", true do |meth_name|
            meth = get_method_or_raise(meth_name, target, {})
            text.no_color do
              self.content << process_comment_markup(meth.doc, self.code_type)
            end
            self.code_type = :plain
          end
          opt.on :c, :command, "Gist a command's source.", true do |command_name|
            command = find_command(command_name)
            block = Pry::Method.new(find_command(command_name).block)
            self.content << block.source
          end
          opt.on :f, :file, "Gist a file.", true do |file|
            self.content << File.read(File.expand_path(file))
          end
          opt.on :p, :public, "Create a public gist (default: false)", :default => false
          opt.on :l, :lines, "Only gist a subset of lines.", :optional => true, :as => Range, :default => 1..-1
          opt.on :i, :in, "Gist entries from Pry's input expression history. Takes an index or range.", :optional => true,
          :as => Range, :default => -5..-1 do |range|
            range = convert_to_range(range)
            input_expressions = _pry_.input_array[range] || []
            Array(input_expressions).each_with_index do |code, index|
              corrected_index = index + range.first
              if code && code != ""
                self.content << code
                if code !~ /;\Z/
                  self.content << "#{comment_expression_result_for_gist(Pry.config.gist.inspecter.call(_pry_.output_array[corrected_index]))}"
                end
              end
            end
          end
        end

        def process
          perform_gist
        end

        def perform_gist
          type_map = { :ruby => "rb", :c => "c", :plain => "plain" }

          if self.content =~ /\A\s*\z/
            raise CommandError, "Found no code to gist."
          end

          # prevent Gist from exiting the session on error
          begin
            extname = opts.present?(:file) ? ".#{gist_file_extension(opts[:f])}" : ".#{type_map[self.code_type]}"

            if opts.present?(:lines)
              self.content = restrict_to_lines(content, opts[:l])
            end

            link = Gist.write([:extension => extname,
                               :input => self.content],
                              !opts[:p])
          rescue SystemExit
          end

          if link
            Gist.copy(link)
            output.puts "Gist created at #{link} and added to clipboard."
          end
        end

        def gist_file_extension(file_name)
          file_name.split(".").last
        end

        def convert_to_range(n)
          if !n.is_a?(Range)
            (n..n)
          else
            n
          end
        end

        def comment_expression_result_for_gist(result)
          content = ""
          result.lines.each_with_index do |line, index|
            if index == 0
              content << "# => #{line}"
            else
              content << "#    #{line}"
            end
          end
          content
        end
      end
    end
  end
end

