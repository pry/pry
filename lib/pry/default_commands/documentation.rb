class Pry
  module DefaultCommands

    Documentation = Pry::CommandSet.new do

      command "ri", "View ri documentation. e.g `ri Array#each`" do |*args|
        run ".ri", *args
      end

      command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?", :shellwords => false do |*args|
        opts, meth = parse_options!(args, :method_object) do |opt|
          opt.banner unindent <<-USAGE
            Usage: show-doc [OPTIONS] [METH]
            Show the comments above method METH. Tries instance methods first and then methods by default.
            e.g show-doc hello_method
          USAGE

          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        raise Pry::CommandError, "No documentation found." if meth.doc.nil? || meth.doc.empty?

        doc = process_comment_markup(meth.doc, meth.source_type)
        output.puts make_header(meth, doc)
        output.puts "#{text.bold("Owner:")} #{meth.owner || "N/A"}"
        output.puts "#{text.bold("Visibility:")} #{meth.visibility}"
        output.puts "#{text.bold("Signature:")} #{meth.signature}"
        output.puts
        render_output(opts.present?(:flood), false, doc)
      end

      alias_command "?", "show-doc"

      command "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info.", :shellwords => false do |*args|
        target = target()

        opts, meth = parse_options!(args, :method_object) do |opt|
          opt.banner unindent <<-USAGE
            Usage: stat [OPTIONS] [METH]
            Show method information for method METH and set _file_ and _dir_ locals.
            e.g: stat hello_method
          USAGE
        end

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

      command "gist", "Gist a method or expression history to github. Type `gist --help` for more info.", :requires_gem => "gist", :shellwords => false do |*args|
        require 'gist'

        target = target()

        opts = parse_options!(args) do |opt|
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
          opt.on :p, :public, "Create a public gist (default: false)", :default => false
          opt.on :i, :in, "Gist entries from Pry's input expression history. Takes an index or range.", :optional => true, :as => Range, :default => -5..-1
        end

        type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
        if opts.present?(:in)
          code_type = :ruby
          content = ""
          normalized_range = absolute_index_range(opts[:i], _pry_.input_array.length)
          input_items = _pry_.input_array[normalized_range] || []

          input_items.each_with_index.map do |code, index|
            corrected_index = index + normalized_range.first
            if code && code != ""
              content << code
              content << "#{comment_expression_result_for_gist(_pry_.output_array[corrected_index].pretty_inspect)}" if code !~ /;\Z/
            end
          end
        elsif opts.present?(:doc)
          meth = get_method_or_raise(opts[:d], target, {})
          content = meth.doc
          code_type = meth.source_type

          text.no_color do
            content = process_comment_markup(content, code_type)
          end
          code_type = :plain
        elsif opts.present?(:method)
          meth = get_method_or_raise(opts[:m], target, {})
          content = meth.source
          code_type = meth.source_type
        end

        # prevent Gist from exiting the session on error
        begin
        link = Gist.write([:extension => ".#{type_map[code_type]}",
                           :input => content],
                          !opts[:p])
        rescue SystemExit
        end

        if link
          Gist.copy(link)
          output.puts "Gist created at #{link} and added to clipboard."
        end
      end


      helpers do
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
