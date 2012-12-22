class Pry
  Pry::Commands.create_command "show-source" do
    extend  Pry::Helpers::BaseHelpers

    group 'Introspection'
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
      e.g: `show-source Pry --super      # source for superclass of Pry (Object class)

      https://github.com/pry/pry/wiki/Source-browsing#wiki-Show_method
    BANNER

    options :shellwords => false
    options :requires_gem => "ruby18_source_location" if mri_18?

    def setup
      require 'ruby18_source_location' if mri_18?
    end

    def options(opt)
      opt.on :s, :super, "Select the 'super' method. Can be repeated to traverse the ancestors.", :as => :count
      opt.on :l, "line-numbers", "Show line numbers."
      opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
      opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
      opt.on :a, :all, "Show source for all definitions and monkeypatches of the module/class"
    end

    def process
      code_object = Pry::CodeObject.lookup obj_name, target, _pry_, :super => opts[:super]

      if !code_object
        raise Pry::CommandError, "Couldn't locate #{obj_name}!"
      end

      if code_object.is_a?(Pry::WrappedModule) && opts.present?(:all)
        # show all monkey patches for a module
        result = source_for_all_module_candidates(code_object)
      else
        # show the source for a specific code object
        result = header(code_object)
        result << Code.new(code_object.source, start_line_for(code_object)).
          with_line_numbers(use_line_numbers?).to_s

        set_file_and_dir_locals(code_object.source_file)
      end

      stagger_output result
    end

    def obj_name
      @obj_name ||= args.empty? ? nil : args.join(" ")
    end

    # we need this helper as some Pry::Method objects can wrap Procs
    # @return [Boolean]
    def real_method_object?(code_object)
      code_object.is_a?(::Method) || code_object.is_a?(::UnboundMethod)
    end

    # Generate a header (meta-data information) for all the code
    # object types: methods, modules, commands, procs...
    def header(code_object)
      file_name, line_num = code_object.source_file, code_object.source_line
      h = "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} "
      if real_method_object?(code_object) && code_object.source_type == :c
        h << "(C Method):"
      else
        h << "@ line #{line_num}:"
      end

      if real_method_object?(code_object)
        h << "\n#{text.bold("Owner:")} #{code_object.owner || "N/A"}\n"
        h << "#{text.bold("Visibility:")} #{code_object.visibility}"
      end
      h << "\n#{Pry::Helpers::Text.bold('Number of lines:')} #{code_object.source.lines.count}\n\n"
    end

    def source_for_all_module_candidates(mod)
      result = "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
      mod.number_of_candidates.times do |v|
        candidate = mod.candidate(v)
        begin
          result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.file} @ line #{candidate.line}:\n"
          code = Code.from_module(mod, start_line_for(candidate), v).with_line_numbers(use_line_numbers?).to_s
          result << "Number of lines: #{code.lines.count}\n\n" << code
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
        code_object.source_line || 1
      end
    end

    def use_line_numbers?
      opts.present?(:b) || opts.present?(:l)
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

  Pry::Commands.alias_command "show-method", "show-source"
  Pry::Commands.alias_command "$", "show-source"
end
