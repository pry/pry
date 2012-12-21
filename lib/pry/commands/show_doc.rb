class Pry
  Pry::Commands.create_command "show-doc" do
    include Pry::Helpers::DocumentationHelpers
    extend  Pry::Helpers::BaseHelpers

    group 'Introspection'
    description "Show the documentation for a method or class. Aliases: \?"
    command_options :shellwords => false
    command_options :requires_gem => "ruby18_source_location" if mri_18?

    banner <<-BANNER
      Usage: show-doc [OPTIONS] [METH]
      Aliases: ?

      Show the documentation for a method or class. Tries instance methods first and then methods by default.
      e.g show-doc hello_method    # docs for hello_method
      e.g show-doc Pry             # docs for Pry class
      e.g show-doc Pry -a          # docs for all definitions of Pry class (all monkey patches)
    BANNER

    def setup
      require 'ruby18_source_location' if mri_18?
    end

    def options(opt)
      opt.on :s, :super, "Select the 'super' method. Can be repeated to traverse the ancestors.", :as => :count
      opt.on :l, "line-numbers", "Show line numbers."
      opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
      opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
      opt.on :a, :all, "Show docs for all definitions and monkeypatches of the module/class"
    end


    def process
      code_object = Pry::CodeObject.lookup(obj_name, target, _pry_, :super => opts[:super])

      if !code_object
        raise Pry::CommandError, "Couldn't locate #{obj_name}!"
      end

      if code_object.is_a?(Pry::WrappedModule) && opts.present?(:all)
        # show all monkey patches for a module
        result = docs_for_all_module_candidates(code_object)
      else
        # show the source for a specific code object
        result = header(code_object)
        result << Code.new(render_doc_markup_for(code_object), start_line_for(code_object), :text).
          with_line_numbers(use_line_numbers?).to_s
      end

      stagger_output result
    end

    def render_doc_markup_for(code_object)
      if code_object.is_a?(Module) && code_object <= Pry::Command
        # command 'help' doesn't want markup highlighting
        code_object.doc
      elsif code_object.is_a?(WrappedModule) && code_object.yard_docs?
        # yard docs
        process_comment_markup(code_object.yard_doc)
      else
        # normal docs (i.e comments above method/module)
        process_comment_markup(code_object.doc)
      end
    end

    def obj_name
      @obj_name ||= args.empty? ? nil : args.join(" ")
    end

    # we need this helper as some Pry::Method objects can wrap Procs
    # @return [Boolean]
    def real_method_object?(code_object)
      code_object.is_a?(::Method) || code_object.is_a?(::UnboundMethod)
    end

    # takes into account possible yard docs, and returns yard_file / yard_line
    def file_and_line_for(code_object)
      if code_object.is_a?(WrappedModule) && code_object.yard_docs?
        [code_object.yard_file, code_object.yard_line]
      else
        [code_object.source_file, code_object.source_line]
      end
    end

    # Generate a header (meta-data information) for all the code
    # object types: methods, modules, commands, procs...
    def header(code_object)
      file_name, line_num = file_and_line_for(code_object)
      h = "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} "
      if real_method_object?(code_object) && code_object.source_type == :c
        h << "(C Method):"
      else
        h << "@ line #{line_num}:"
      end

      if real_method_object?(code_object)
        h << "\n#{text.bold("Owner:")} #{code_object.owner || "N/A"}\n"
        h << "#{text.bold("Visibility:")} #{code_object.visibility}\n"
        h << "#{text.bold("Signature:")} #{code_object.signature}"
      end
      h << "\n#{Pry::Helpers::Text.bold('Number of lines:')} #{code_object.source.lines.count}\n\n"
    end

    def docs_for_all_module_candidates(mod)
      result = "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
      mod.number_of_candidates.times do |v|
        candidate = mod.candidate(v)
        begin
          result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.file} @ line #{candidate.line}:\n"
          doc = candidate.doc
          result << "Number of lines: #{doc.lines.count}\n\n" << doc
        rescue Pry::RescuableException
          result << "\nNo code found.\n"
          next
        end
      end
      result
    end

    def start_line_for(code_object)
      if opts.present?(:'base-one')
         1
      else
        code_object.source_line.nil? ? 1 :
          (code_object.source_line - code_object.doc.lines.count)
      end
    end

    def use_line_numbers?
      opts.present?(:b) || opts.present?(:l)
    end
  end
  Pry::Commands.alias_command "?", "show-doc"
end
