class Pry
  Pry::Commands.create_command "show-doc" do
    include Pry::Helpers::ModuleIntrospectionHelpers
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
      method_options(opt)
      opt.on :l, "line-numbers", "Show line numbers."
      opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
      opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
      opt.on :a, :all, "Show docs for all definitions and monkeypatches of the module/class"
    end

    def process_sourcable_object
      name = args.first
      object = target.eval(name)

      file_name, line = object.source_location

      doc = Pry::Code.from_file(file_name).comment_describing(line)
      doc = strip_leading_hash_and_whitespace_from_ruby_comments(doc)

      result = ""
      result << "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} @ line #{line}:\n"
      result << "#{Pry::Helpers::Text.bold('Number of lines:')} #{doc.lines.count}\n\n"
      result << doc
      result << "\n"
    end

    def process_module
      raise Pry::CommandError, "No documentation found." if module_object.nil?
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

      doc = Pry::Code.new(doc, start_line, :text).
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
        doc = Pry::Code.new(doc, start_line, :text).
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

  Pry::Commands.alias_command "?", "show-doc"
end
