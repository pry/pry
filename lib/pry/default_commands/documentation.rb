class Pry
  module DefaultCommands

    Documentation = Pry::CommandSet.new do

      command_class "ri", "View ri documentation. e.g `ri Array#each`" do
        banner <<-BANNER
          Usage: ri [spec]
          e.g. ri Array#each

          Relies on the ri executable being available. See also: show-doc.
        BANNER

        def process
          run ".ri", *args
        end
      end

      command_class "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?", :shellwords => false do |*args|
        banner <<-BANNER
          Usage: show-doc [OPTIONS] [METH]
          Show the comments above method METH. Tries instance methods first and then methods by default.
          e.g show-doc hello_method
        BANNER

        def options(opt)
          method_options(opt)
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

          render_output(doc, opts)
        end
      end

      alias_command "?", "show-doc"

      command_class "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info.", :shellwords => false do |*args|
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

      command_class "gist", "Gist a method or expression history to github. Type `gist --help` for more info.", :requires_gem => "gist", :shellwords => false do
        attr_accessor :content
        attr_accessor :code_type
        attr_accessor :input_ranges

        def setup
          require 'gist'
        end

        def options(opt)
          opt.banner unindent <<-USAGE
  Usage: gist [OPTIONS] [METH]
  Gist method (doc or source) or input expression to github.
  Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
  e.g: gist -m my_method
  e.g: gist -d my_method
  e.g: gist -i 1..10
USAGE

          opt.on :d, :doc, "Gist a method's documentation.", true
          opt.on :m, :method, "Gist a method's source.", true
          opt.on :f, :file, "Gist a file.", true
          opt.on :p, :public, "Create a public gist (default: false)", :default => false
          opt.on :l, :lines, "Only gist a subset of lines (only works with -m and -f)", :optional => true, :as => Range, :default => 1..-1
          opt.on :i, :in, "Gist entries from Pry's input expression history. Takes an index or range.", :optional => true,
          :as => Range, :default => -5..-1 do |range|
            self.input_ranges ||= []
            input_ranges << absolute_index_range(range, _pry_.input_array.length)
          end
        end

        def process
          self.content = ""

          if opts.present?(:in)
            in_option
          end
          if opts.present?(:file)
            file_option
          end
          if opts.present?(:doc)
            doc_option
          end
          if opts.present?(:method)
            method_option
          end

          perform_gist
        end

        def in_option
          self.code_type = :ruby

          input_ranges.each do |range|
            input_expressions = _pry_.input_array[range] || []
            input_expressions.each_with_index.map do |code, index|
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

        def file_option
          whole_file = File.read(File.expand_path(opts[:f]))
          if opts.present?(:lines)
            self.content << restrict_to_lines(whole_file, opts[:l])
          else
            self.content << whole_file
          end
        end

        def doc_option
          meth = get_method_or_raise(opts[:d], target, {})
          self.content << meth.doc
          self.code_type = meth.source_type

          text.no_color do
            self.content << process_comment_markup(self.content, self.code_type)
          end
          self.code_type = :plain
        end

        def method_option
          meth = get_method_or_raise(opts[:m], target, {})
          method_source = meth.source
          if opts.present?(:lines)
            self.content << restrict_to_lines(method_source, opts[:l])
          else
            self.content << method_source
          end

          self.code_type = meth.source_type
        end

        def perform_gist
          type_map = { :ruby => "rb", :c => "c", :plain => "plain" }

          # prevent Gist from exiting the session on error
          begin
            extname = opts.present?(:file) ? ".#{gist_file_extension(opts[:f])}" : ".#{type_map[self.code_type]}"

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

        def restrict_to_lines(content, lines)
          line_range = one_index_range(lines)
          content.lines.to_a[line_range].join
        end

        def gist_file_extension(file_name)
          file_name.split(".").last
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

