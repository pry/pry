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
          meth_name = method_name
          if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
            output.puts "Invalid method name: #{meth_name}. Type `show-doc --help` for help"
            next
          end

          doc, code_type = doc_and_code_type_for(meth)
          next if !doc

          next output.puts("No documentation found.") if doc.empty?
          doc = process_comment_markup(doc, code_type)
          output.puts make_header(meth, code_type, doc)
          output.puts "#{text.bold("visibility: ")} #{method_visibility(meth).to_s}"
          output.puts "#{text.bold("signature: ")} #{signature_for(meth)}"
          output.puts
          render_output(opts.flood?, false, doc)
          doc
        end
      end

      alias_command "?", "show-doc", ""

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
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `stat --help` for help"
          next
        end

        if !is_a_c_method?(meth) && !is_a_dynamically_defined_method?(meth)
          set_file_and_dir_locals(path_line_for(meth).first)
        end

        output.puts "Method Information:"
        output.puts "--"
        output.puts "Name: " + meth_name
        output.puts "Owner: " + (meth.owner.to_s ? meth.owner.to_s : "Unknown")
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
        if (meth = get_method_object(meth_name, target, opts.to_hash(true))).nil?
          output.puts "Invalid method name: #{meth_name}. Type `gist-method --help` for help"
          next
        end

        type_map = { :ruby => "rb", :c => "c", :plain => "plain" }
        if !opts.doc?
          content, code_type = code_and_code_type_for(meth)
        else
          content, code_type = doc_and_code_type_for(meth)
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

      helpers do

        # paraphrased from awesome_print gem
        def signature_for(method)
          if method.respond_to?(:parameters)

            args = method.parameters.inject([]) do |arr, (type, name)|
              name ||= (type == :block ? 'block' : "arg#{arr.size + 1}")
              arr << case type
                     when :req        then name.to_s
                     when :opt, :rest then "*#{name}"
                     when :block      then "&#{name}"
                     else '?'
                     end
            end
          else 
            args = (1..method.arity.abs).map { |i| "arg#{i}" }
            args[-1] = "*#{args[-1]}" if method.arity < 0
          end

          "#{method.name}(#{args.join(', ')})"
        end
        
        def method_visibility(meth)
          if meth.owner.public_instance_methods.include? meth.name
            :public
          elsif meth.owner.protected_instance_methods.include? meth.name
            :protected
          elsif meth.owner.private_instance_methods.include? meth.name
            :private
          else
            :none
          end
        end
      end

    end

  end
end
