class Pry
  Pry::Commands.create_command "show-source" do
    include Pry::Helpers::ModuleIntrospectionHelpers
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
      method_options(opt)
      opt.on :l, "line-numbers", "Show line numbers."
      opt.on :b, "base-one", "Show line numbers but start numbering at 1 (useful for `amend-line` and `play` commands)."
      opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
      opt.on :a, :all, "Show source for all definitions and monkeypatches of the module/class"
    end

    def process_sourcable_object
      name = args.first
      object = target.eval(name)

      file_name, line = object.source_location

      source = Pry::Code.from_file(file_name).expression_at(line)
      code   = Pry::Code.new(source).with_line_numbers(use_line_numbers?).to_s

      result = ""
      result << "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} @ line #{line}:\n"
      result << "#{Pry::Helpers::Text.bold('Number of lines:')} #{code.lines.count}\n\n"
      result << code
      result << "\n"
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
      raise Pry::CommandError, "No documentation found." if module_object.nil?
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

  Pry::Commands.alias_command "show-method", "show-source"
  Pry::Commands.alias_command "$", "show-source"
end
