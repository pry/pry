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
        render_output(opts.flood?, false, doc)
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

      command "gist-method", "Gist a method to github. Type `gist-method --help` for more info.", :requires_gem => "gist", :shellwords => false do |*args|
        require 'gist'

        target = target()

        opts, meth = parse_options!(args, :method_object) do |opt|
          opt.banner unindent <<-USAGE
            Usage: gist-method [OPTIONS] [METH]
            Gist the method (doc or source) to github.
            Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
            e.g: gist -m my_method
            e.g: gist -d my_method
          USAGE

          opt.on :d, :doc, "Gist a method's documentation."
          opt.on :p, :private, "Create a private gist (default: true)", :default => true
        end

        type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
        if !opts.doc?
          content = meth.source
          code_type = meth.source_type
        else
          content = meth.doc
          code_type = meth.source_type

          text.no_color do
            content = process_comment_markup(content, code_type)
          end
          code_type = :plain
        end

        link = Gist.write([:extension => ".#{type_map[code_type]}",
                           :input => content],
                          opts.p?)

        output.puts "Gist created at #{link}"
      end
    end
  end
end
