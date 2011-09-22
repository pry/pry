class Pry
  module DefaultCommands

    Documentation = Pry::CommandSet.new do

      command "ri", "View ri documentation. e.g `ri Array#each`" do |*args|
        run ".ri", *args
      end

      command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: show-doc [OPTIONS] [METH 1] [METH 2] [METH N]
            Show the comments above method METH. Tries instance methods first and then methods by default.
            e.g show-doc hello_method
          USAGE

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        args = [nil] if args.empty?
        args.each do |method_name|
          if (method = Pry::Method.from_str(method_name, target, opts.to_hash(true))).nil?
            output.puts "Invalid method name: #{method_name}. Type `show-doc --help` for help"
            next
          end

          next unless method.doc
          set_file_and_dir_locals(method.source_file)

          next output.puts("No documentation found.") if method.doc.empty?

          doc = process_comment_markup(method.doc, method.source_type)
          output.puts make_header(method, doc)
          output.puts "#{text.bold("visibility: ")} #{method.visibility}"
          output.puts "#{text.bold("signature:  ")} #{method.signature}"
          output.puts
          render_output(opts.flood?, false, doc)
          doc
        end
      end

      alias_command "?", "show-doc"

      command "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: stat [OPTIONS] [METH]
            Show method information for method METH and set _file_ and _dir_ locals.
            e.g: stat hello_method
          USAGE

          opt.on :M, "instance-methods", "Operate on instance methods."
          opt.on :m, :methods, "Operate on methods."
          opt.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opt.on :h, :help, "This message" do
            output.puts opt
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (method = Pry::Method.from_str(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `stat --help` for help"
          next
        end

        if method.source_type != :c and !method.dynamically_defined?
          set_file_and_dir_locals(method.source_file)
        end

        output.puts "Method Information:"
        output.puts "--"
        output.puts "Name: " + meth_name
        output.puts "Owner: " + (method.owner ? method.owner.to_s : "Unknown")
        output.puts "Visibility: " + method_visibility(meth).to_s
        output.puts "Type: " + (meth.is_a?(Method) ? "Bound" : "Unbound")
        output.puts "Arity: " + meth.arity.to_s
        output.puts "Method Signature: " + signature_for(meth)

        output.puts "Source location: " + (meth.source_location ? meth.source_location.join(":") : "Not found.")
      end

      command "gist-method", "Gist a method to github. Type `gist-method --help` for more info.", :requires_gem => "gist" do |*args|
        require 'gist'

        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: gist-method [OPTIONS] [METH]
            Gist the method (doc or source) to github.
            Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
            e.g: gist -m my_method
            e.g: gist -d my_method
          USAGE

          opt.on :m, :method, "Gist a method's source."
          opt.on :d, :doc, "Gist a method's documentation."
          opt.on :p, :private, "Create a private gist (default: true)", :default => true
          opt.on :h, :help, "This message" do
            output.puts opt
          end
        end

        next if opts.help?

        # This needs to be extracted into its own method as it's shared
        # by show-method and show-doc and stat commands
        meth_name = args.shift
        if (method = Pry::Method.from_str(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `gist-method --help` for help"
          next
        end

        type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
        if !opts.doc?
          content = method.source
          code_type = method.source_type
        else
          content = method.doc
          code_type = method.source_type

          text.no_color do
            content = process_comment_markup(content, code_type)
          end
          code_type = :plain
        end

        link = Gist.write([:extension => ".#{type_map[code_type]}",
                           :input => content],
                          opts.p?)

        output.puts "Gist created at #{link}"

        set_file_and_dir_locals(method.source_file)
      end
    end
  end
end
