require 'tempfile'

class Pry
  module DefaultCommands

    # For show-doc and show-source
    module ModuleIntrospectionHelpers
      attr_accessor :module_object

      def module?(name)
        self.module_object = Pry::WrappedModule.from_str(name, target)
      end

      def method?
        !!method_object
      rescue CommandError
        false
      end

      def process(name)
        if module?(name)
          code_or_doc = process_module
        elsif method?
          code_or_doc = process_method
        else
          code_or_doc = process_alternatives
        end

        render_output(code_or_doc, opts)
      end

      def process_alternatives
        if args.empty? && internal_binding?(target)
          mod = target_self.is_a?(Module) ? target_self : target_self.class
          self.module_object = Pry::WrappedModule(mod)

          process_module
        else
          process_method
        end
      end

      def module_start_line(mod, candidate_rank=0)
        if opts.present?(:'base-one')
          1
        else
          mod.candidate(candidate_rank).line
        end
      end

      def use_line_numbers?
        opts.present?(:b) || opts.present?(:l)
      end

      def attempt
        rank = 0
        begin
          yield(rank)
        rescue Pry::CommandError
          raise if rank > (module_object.number_of_candidates - 1)
          rank += 1
          retry
        end
      end
    end

    Introspection = Pry::CommandSet.new do

      create_command "show-doc", "Show the documentation for a method or class. Aliases: \?", :shellwords => false do
        include ModuleIntrospectionHelpers
        include Helpers::DocumentationHelpers
        extend Helpers::BaseHelpers

        banner <<-BANNER
          Usage: show-doc [OPTIONS] [METH]
          Aliases: ?

          Show the documentation for a method or class. Tries instance methods first and then methods by default.
          e.g show-doc hello_method    # docs for hello_method
          e.g show-doc Pry             # docs for Pry class
          e.g show-doc Pry -a          # docs for all definitions of Pry class (all monkey patches)
        BANNER

        options :requires_gem => "ruby18_source_location" if mri_18?

        def setup
          require 'ruby18_source_location' if mri_18?
        end

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :a, :all, "Show docs for all definitions and monkeypatches of the module/class"
        end

        def process_module
          if opts.present?(:all)
            all_modules
          else
            normal_module
          end
        end

        def normal_module
          doc = ""
          if module_object.yard_docs?
            file_name, line = module_object.yard_file, module_object.yard_line
            doc << module_object.yard_doc
            start_line = 1
          else
            attempt do |rank|
              file_name, line = module_object.candidate(rank).source_location
              set_file_and_dir_locals(file_name)
              doc << module_object.candidate(rank).doc
              start_line = module_start_line(module_object, rank)
            end
          end

          doc = Code.new(doc, start_line, :text).
            with_line_numbers(use_line_numbers?).to_s

          doc.insert(0, "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} @ line #{line ? line : "N/A"}:\n\n")
        end

        def all_modules
          doc = ""
          doc << "Found #{module_object.number_of_candidates} candidates for `#{module_object.name}` definition:\n"
          module_object.number_of_candidates.times do |v|
            candidate = module_object.candidate(v)
            begin
              doc << "\nCandidate #{v+1}/#{module_object.number_of_candidates}: #{candidate.file} @ #{candidate.line}:\n\n"
              doc << candidate.doc
            rescue Pry::RescuableException
              doc << "No documentation found.\n"
              next
            end
          end
          doc
        end

        def process_method
          raise Pry::CommandError, "No documentation found." if method_object.doc.nil? || method_object.doc.empty?

          doc = process_comment_markup(method_object.doc)
          output.puts make_header(method_object, doc)
          output.puts "#{text.bold("Owner:")} #{method_object.owner || "N/A"}"
          output.puts "#{text.bold("Visibility:")} #{method_object.visibility}"
          output.puts "#{text.bold("Signature:")} #{method_object.signature}"
          output.puts

          if use_line_numbers?
            doc = Code.new(doc, start_line, :text).
              with_line_numbers(true).to_s
          end

          doc
        end

        def module_start_line(mod, candidate=0)
          if opts.present?(:'base-one')
            1
          else
            if mod.candidate(candidate).line
              mod.candidate(candidate).line - mod.candidate(candidate).doc.lines.count
            else
              1
            end
          end
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

      create_command "stat", "View method information and set _file_ and _dir_ locals.", :shellwords => false do
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

      create_command "show-source" do
        include ModuleIntrospectionHelpers
        extend Helpers::BaseHelpers

        description "Show the source for a method or class. Aliases: $, show-method"

        banner <<-BANNER
          Usage: show-source [OPTIONS] [METH|CLASS]
          Aliases: $, show-method

          Show the source for a method or class. Tries instance methods first and then methods by default.

          e.g: `show-source hello_method`
          e.g: `show-source -m hello_method`
          e.g: `show-source Pry#rep`         # source for Pry#rep method
          e.g: `show-source Pry`             # source for Pry class
          e.g: `show-source Pry -a`          # source for all Pry class definitions (all monkey patches)

          https://github.com/pry/pry/wiki/Source-browsing#wiki-Show_method
        BANNER

        options :shellwords => false
        options :requires_gem => "ruby18_source_location" if mri_18?

        def setup
          require 'ruby18_source_location' if mri_18?
        end

        def options(opt)
          method_options(opt)
          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :a, :all, "Show source for all definitions and monkeypatches of the module/class"
        end

        def process_method
          raise CommandError, "Could not find method source" unless method_object.source

          code = ""
          code << make_header(method_object)
          code << "#{text.bold("Owner:")} #{method_object.owner || "N/A"}\n"
          code << "#{text.bold("Visibility:")} #{method_object.visibility}\n"
          code << "\n"

          code << Code.from_method(method_object, start_line).
                   with_line_numbers(use_line_numbers?).to_s
        end

        def process_module
          if opts.present?(:all)
            all_modules
          else
            normal_module
          end
        end

        def normal_module
          file_name = line = code = nil
          attempt do |rank|
            file_name, line = module_object.candidate(rank).source_location
            set_file_and_dir_locals(file_name)
            code = Code.from_module(module_object, module_start_line(module_object, rank), rank).
              with_line_numbers(use_line_numbers?).to_s
          end

          result = ""
          result << "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} @ line #{line}:\n"
          result << "#{Pry::Helpers::Text.bold('Number of lines:')} #{code.lines.count}\n\n"
          result << code
        end

        def all_modules
          mod = module_object

          result = ""
          result << "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
          mod.number_of_candidates.times do |v|
            candidate = mod.candidate(v)
            begin
              result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.file} @ line #{candidate.line}:\n"
              code = Code.from_module(mod, module_start_line(mod, v), v).
                with_line_numbers(use_line_numbers?).to_s
              result << "Number of lines: #{code.lines.count}\n\n"
              result << code
            rescue Pry::RescuableException
              result << "\nNo code found.\n"
              next
            end
          end
          result
        end

        def use_line_numbers?
          opts.present?(:b) || opts.present?(:l)
        end

        def start_line
          if opts.present?(:'base-one')
            1
          else
            method_object.source_line || 1
          end
        end
      end

      alias_command "show-method", "show-source"
      alias_command "$", "show-source"

      command "show-command", "Show the source for CMD." do |*args|
        target = target()

        opts = Slop.parse!(args) do |opt|
          opt.banner unindent <<-USAGE
            Usage: show-command [OPTIONS] [CMD]
            Show the source for command CMD.
            e.g: show-command show-method
          USAGE

          opt.on :l, "line-numbers", "Show line numbers."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
          opt.on :h, :help, "This message." do
            output.puts opt.help
          end
        end

        next if opts.present?(:help)

        command_name = args.shift
        if !command_name
          raise CommandError, "You must provide a command name."
        end

        if find_command(command_name)
          block = Pry::Method.new(find_command(command_name).block)

          next unless block.source
          set_file_and_dir_locals(block.source_file)

          output.puts make_header(block)
          output.puts

          code = Code.from_method(block).with_line_numbers(opts.present?(:'line-numbers')).to_s

          render_output(code, opts)
        else
          raise CommandError, "No such command: #{command_name}."
        end
      end

      create_command "ri", "View ri documentation. e.g `ri Array#each`" do
        banner <<-BANNER
          Usage: ri [spec]
          e.g. ri Array#each

          Relies on the rdoc gem being installed. See also: show-doc.
        BANNER

        def process(spec)
          # Lazily load RI
          require 'rdoc/ri/driver'

          unless defined? RDoc::RI::PryDriver

            # Subclass RI so that it formats its output nicely, and uses `lesspipe`.
            subclass = Class.new(RDoc::RI::Driver) # the hard way.

            subclass.class_eval do
              def page
                Pry::Helpers::BaseHelpers.lesspipe {|less| yield less}
              end

              def formatter(io)
                if @formatter_klass then
                  @formatter_klass.new
                else
                  RDoc::Markup::ToAnsi.new
                end
              end
            end

            RDoc::RI.const_set :PryDriver, subclass   # hook it up!
          end

          # Spin-up an RI insance.
          ri = RDoc::RI::PryDriver.new :use_stdout => true, :interactive => false

          begin
            ri.display_names [spec]  # Get the documentation (finally!)
          rescue RDoc::RI::Driver::NotFoundError => e
            output.puts "error: '#{e.name}' not found"
          end
        end

      end

    end
  end
end

