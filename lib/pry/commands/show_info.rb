class Pry
  class Command::ShowInfo < Pry::ClassCommand
    extend Pry::Helpers::BaseHelpers

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
      opt.on :a, :all, "Show all definitions and monkeypatches of the module/class"
    end

    def process

      code_object = Pry::CodeObject.lookup(obj_name, target, _pry_, :super => opts[:super])
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
