class Pry
  module DefaultCommands

    Documentation = Pry::CommandSet.new :gems do

      command "ri", "View ri documentation. e.g `ri Array#each`" do |*args|
        run ".ri", *args
      end

      command "show-doc", "Show the comments above METH. Type `show-doc --help` for more info. Aliases: \?" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opts|
          opts.banner %{Usage: show-doc [OPTIONS] [METH]
Show the comments above method METH. Tries instance methods first and then methods by default.
e.g show-doc hello_method
--
}
          opts.on :M, "instance-methods", "Operate on instance methods."
          opts.on :m, :methods, "Operate on methods."
          opts.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opts.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opts.on :h, :help, "This message." do
            output.puts opts
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `show-doc --help` for help"
          next
        end

        doc, code_type = doc_and_code_type_for(meth)
        next if !doc

        next output.puts("No documentation found.") if doc.empty?
        doc = process_comment_markup(doc, code_type)
        output.puts make_header(meth, code_type, doc)
        render_output(opts.flood?, false, doc)
        doc
      end

      alias_command "?", "show-doc", ""


      command "stat", "View method information and set _file_ and _dir_ locals. Type `stat --help` for more info." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opts|
          opts.banner %{Usage: stat [OPTIONS] [METH]
Show method information for method METH and set _file_ and _dir_ locals.
e.g: stat hello_method
--
}
          opts.on :M, "instance-methods", "Operate on instance methods."
          opts.on :m, :methods, "Operate on methods."
          opts.on :c, :context, "Select object context to run under.", true do |context|
            target = Pry.binding_for(target.eval(context))
          end
          opts.on :h, :help, "This message" do
            output.puts opts
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `stat --help` for help"
          next
        end

        code, code_type = code_and_code_type_for(meth)
        next if !code
        doc, code_type = doc_and_code_type_for(meth)

        output.puts make_header(meth, code_type, code)
        output.puts bold("Method Name: ") + meth_name
        output.puts bold("Method Owner: ") + (meth.owner.to_s ? meth.owner.to_s : "Unknown")
        output.puts bold("Method Language: ") + code_type.to_s.capitalize
        output.puts bold("Method Type: ") + (meth.is_a?(Method) ? "Bound" : "Unbound")
        output.puts bold("Method Arity: ") + meth.arity.to_s

        name_map = { :req => "Required:", :opt => "Optional:", :rest => "Rest:" }
        if meth.respond_to?(:parameters)
          output.puts bold("Method Parameters: ") + meth.parameters.group_by(&:first).
            map { |k, v| "#{name_map[k]} #{v.map { |kk, vv| vv ? vv.to_s : "noname" }.join(", ")}" }.join(". ")
        end
        output.puts bold("Comment length: ") + (doc.empty? ? 'No comment.' : (doc.lines.count.to_s + ' lines.'))
      end

      command "gist-method", "Gist a method to github. Type `gist-method --help` for more info.", :requires_gem => "gist" do |*args|
        target = target()

        opts = Slop.parse!(args) do |opts|
          opts.banner = %{Usage: gist-method [OPTIONS] [METH]
Gist the method (doc or source) to github.
Ensure the `gist` gem is properly working before use. http://github.com/defunkt/gist for instructions.
e.g: gist -m my_method
e.g: gist -d my_method
--
}
          opts.on :m, :method, "Gist a method's source."
          opts.on :d, :doc, "Gist a method's documentation."
          opts.on :p, :private, "Create a private gist (default: true)", :default => true
          opts.on :h, :help, "This message" do
            output.puts opts
          end
        end

        next if opts.help?

        # This needs to be extracted into its own method as it's shared
        # by show-method and show-doc and stat commands
        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `gist-method --help` for help"
          next
        end

        type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
        if !opts.doc?
          content, code_type = code_and_code_type_for(meth)
        else
          content, code_type = doc_and_code_type_for(meth)
          no_color do
            content = process_comment_markup(content, code_type)
          end
          code_type = :plain
        end

        IO.popen("gist#{' -p' if opts.p?} -t #{type_map[code_type]} -", "w") do |gist|
          gist.puts content
        end
      end

    end

  end
end
