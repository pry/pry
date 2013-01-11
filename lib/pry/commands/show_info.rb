class Pry
  class Command::ShowInfo < Pry::ClassCommand
    extend Pry::Helpers::BaseHelpers

    command_options :shellwords => false
    command_options :requires_gem => "ruby18_source_location" if mri_18?

    def setup
      require 'ruby18_source_location' if mri_18?
    end

    def options(opt)
      opt.on :s, :super, "Select the 'super' method. Can be repeated to traverse the ancestors", :as => :count
      opt.on :l, "line-numbers", "Show line numbers"
      opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)"
      opt.on :f, :flood, "Do not use a pager to view text longer than one screen"
      opt.on :a, :all,   "Show all definitions and monkeypatches of the module/class"
    end

    def process
      code_object = Pry::CodeObject.lookup(obj_name, _pry_, :super => opts[:super])
      raise Pry::CommandError, "Couldn't locate #{obj_name}!" if !code_object

      if show_all_modules?(code_object)
        # show all monkey patches for a module
        result = content_and_headers_for_all_module_candidates(code_object)
      else
        # show a specific code object
        result = content_and_header_for_code_object(code_object)
      end

      set_file_and_dir_locals(code_object.source_file)
      stagger_output result
    end

    def content_and_header_for_code_object(code_object)
      header(code_object) << content_for(code_object)
    end

    def content_and_headers_for_all_module_candidates(mod)
      result = "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
      mod.number_of_candidates.times do |v|
        candidate = mod.candidate(v)
        begin
          result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.source_file} @ line #{candidate.source_line}:\n"
          content = content_for(candidate)

          result << "Number of lines: #{content.lines.count}\n\n" << content
        rescue Pry::RescuableException
          result << "\nNo content found.\n"
          next
        end
      end
      result
    end

    # Generate a header (meta-data information) for all the code
    # object types: methods, modules, commands, procs...
    def header(code_object)
      file_name, line_num = file_and_line_for(code_object)
      h = "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} "
      h << method_header(code_object, line_num) if code_object.real_method_object?
      h << "\n#{Pry::Helpers::Text.bold('Number of lines:')} " <<
        "#{content_for(code_object).lines.count}\n\n"
    end

    def method_header(code_object, line_num)
      h = ""
      h << (code_object.c_method? ? "(C Method):" : "@ line #{line_num}:")
      h << method_sections(code_object)[:owner]
      h << method_sections(code_object)[:visibility]
      h << method_sections(code_object)[:signature]
      h
    end

    def method_sections(code_object)
      {
        :owner => "\n#{text.bold("Owner:")} #{code_object.owner || "N/A"}\n",
        :visibility => "#{text.bold("Visibility:")} #{code_object.visibility}",
        :signature => "\n#{text.bold("Signature:")} #{code_object.signature}"
      }.merge(header_options) { |key, old, new| (new && old).to_s }
    end

    def header_options
      {
        :owner => true,
        :visibility => true,
        :signature => nil
      }
    end

    def show_all_modules?(code_object)
      code_object.is_a?(Pry::WrappedModule) && opts.present?(:all)
    end

    def obj_name
      @obj_name ||= args.empty? ? nil : args.join(" ")
    end

    def use_line_numbers?
      opts.present?(:b) || opts.present?(:l)
    end

    def start_line_for(code_object)
      if opts.present?(:'base-one')
        1
      else
        code_object.source_line || 1
      end
    end

    # takes into account possible yard docs, and returns yard_file / yard_line
    # Also adjusts for start line of comments (using start_line_for), which it has to infer
    # by subtracting number of lines of comment from start line of code_object
    def file_and_line_for(code_object)
      if code_object.module_with_yard_docs?
        [code_object.yard_file, code_object.yard_line]
      else
        [code_object.source_file, start_line_for(code_object)]
      end
    end

    def complete(input)
      if input =~ /([^ ]*)#([a-z0-9_]*)\z/
        prefix, search = [$1, $2]
        methods = begin
                    Pry::Method.all_from_class(binding.eval(prefix))
                  rescue RescuableException => e
                    return super
                  end
        methods.map do |method|
          [prefix, method.name].join('#') if method.name.start_with?(search)
        end.compact
      else
        super
      end
    end
  end
end
