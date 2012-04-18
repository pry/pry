require 'pry/helpers/documentation_helpers'

class Pry
  class << self
    # If the given object is a `Pry::WrappedModule`, return it unaltered. If it's
    # anything else, return it wrapped in a `Pry::WrappedModule` instance.
    def WrappedModule(obj)
      if obj.is_a? Pry::WrappedModule
        obj
      else
        Pry::WrappedModule.new(obj)
      end
    end
  end

  class WrappedModule
    include Helpers::DocumentationHelpers

    attr_reader :wrapped
    private :wrapped

    # Convert a string to a module.
    #
    # @param [String] mod_name
    # @param [Binding] target The binding where the lookup takes place.
    # @return [Module, nil] The module or `nil` (if conversion failed).
    # @example
    #   Pry::WrappedModule.from_str("Pry::Code")
    def self.from_str(mod_name, target=TOPLEVEL_BINDING)
      kind = target.eval("defined?(#{mod_name})")

      # if we dont limit it to constants then from_str could end up
      # executing methods which is not good, i.e `show-source pry`
      if (kind == "constant" && target.eval(mod_name).is_a?(Module))
        Pry::WrappedModule.new(target.eval(mod_name))
      else
        nil
      end
    rescue RescuableException
      nil
    end

    # Create a new WrappedModule
    # @raise ArgumentError, if the argument is not a Module
    # @param [Module]
    def initialize(mod)
      raise ArgumentError, "Tried to initialize a WrappedModule with a non-module #{mod.inspect}" unless ::Module === mod
      @wrapped = mod
      @host_file_lines = nil
      @source = nil
      @source_location = nil
      @doc = nil
    end

    # The prefix that would appear before methods defined on this class.
    #
    # i.e. the "String." or "String#" in String.new and String#initialize.
    #
    # @return String
    def method_prefix
      if singleton_class?
        if Module === singleton_instance
          "#{WrappedModule.new(singleton_instance).nonblank_name}."
        else
          "self."
        end
      else
        "#{nonblank_name}#"
      end
    end

    # The name of the Module if it has one, otherwise #<Class:0xf00>.
    #
    # @return [String]
    def nonblank_name
      if name.to_s == ""
        wrapped.inspect
      else
        name
      end
    end

    # Is this a singleton class?
    # @return [Boolean]
    def singleton_class?
      wrapped != wrapped.ancestors.first
    end

    # Get the instance associated with this singleton class.
    #
    # @raise ArgumentError: tried to get instance of non singleton class
    #
    # @return [Object]
    def singleton_instance
      raise ArgumentError, "tried to get instance of non singleton class" unless singleton_class?

      if Helpers::BaseHelpers.jruby?
        wrapped.to_java.attached
      else
        @singleton_instance ||= ObjectSpace.each_object(wrapped).detect{ |x| (class << x; self; end) == wrapped }
      end
    end

    # Forward method invocations to the wrapped module
    def method_missing(method_name, *args, &block)
      wrapped.send(method_name, *args, &block)
    end

    def respond_to?(method_name)
      super || wrapped.respond_to?(method_name)
    end

    def yard_docs?
      !!(defined?(YARD) && YARD::Registry.at(name))
    end

    def process_doc(doc)
      process_comment_markup(strip_leading_hash_and_whitespace_from_ruby_comments(doc),
                             :ruby)
    end

    def doc
      return @doc if @doc

      file_name, line = source_location

      if yard_docs?
        from_yard = YARD::Registry.at(name)
        @doc = from_yard.docstring
      elsif source_location.nil?
        raise CommandError, "Can't find module's source location"
      else
        @doc = extract_doc_for_candidate(0)
      end

      raise CommandError, "Can't find docs for module: #{name}." if !@doc

      @doc = process_doc(@doc)
    end

    def doc_for_candidate(idx)
      doc = extract_doc_for_candidate(idx)
      raise CommandError, "Can't find docs for module: #{name}." if !doc

      process_doc(doc)
    end

    # Retrieve the source for the module.
    def source
      @source ||= source_for_candidate(0)
    end

    def source_for_candidate(idx)
      file, line = module_source_location_for_candidate(idx)
      raise CommandError, "Could not locate source for #{wrapped}!" if file.nil?

      strip_leading_whitespace(Pry::Code.retrieve_complete_expression_from(lines_for_file(file)[(line - 1)..-1]))
    end

    def source_file
      if yard_docs?
        from_yard = YARD::Registry.at(name)
        from_yard.file
      else
        source_file_for_candidate(0)
      end
    end

    def source_line
      source_line_for_candidate(0)
    end

    def source_file_for_candidate(idx)
      Array(module_source_location_for_candidate(idx)).first
    end

    def source_line_for_candidate(idx)
      Array(module_source_location_for_candidate(idx)).last
    end

    # Retrieve the source location of a module. Return value is in same
    # format as Method#source_location. If the source location
    # cannot be found this method returns `nil`.
    #
    # @param [Module] mod The module (or class).
    # @return [Array<String, Fixnum>] The source location of the
    #   module (or class).
    def source_location
      @source_location ||= module_source_location_for_candidate(0)
    rescue Pry::RescuableException
      nil
    end

    # memoized lines for file
    def lines_for_file(file)
      @lines_for_file ||= {}

      if file == Pry.eval_path
       @lines_for_file[file] ||= Pry.line_buffer.drop(1)
      else
       @lines_for_file[file] ||= File.readlines(file)
      end
    end

    def module_source_location_for_candidate(idx)
      mod_type_string = wrapped.class.to_s.downcase
      file, line = method_source_location_for_candidate(idx)

      return nil if !file.is_a?(String)

      class_regex1 = /#{mod_type_string}\s*(\w*)(::)?#{wrapped.name.split(/::/).last}/
      class_regex2 = /(::)?#{wrapped.name.split(/::/).last}\s*?=\s*?#{wrapped.class}/

      host_file_lines = lines_for_file(file)

      search_lines = host_file_lines[0..(line - 2)]
      idx = search_lines.rindex { |v| class_regex1 =~ v  || class_regex2 =~ v }

      source_location = [file,  idx + 1]
    rescue Pry::RescuableException
      nil
    end

    def extract_doc
      extract_doc_for_candidate(0)
    end

    def extract_doc_for_candidate(idx)
      file_name, line = module_source_location_for_candidate(idx)

      buffer = ""
      lines_for_file(source_file_for_candidate(idx))[0..(line - 2)].each do |line|
        # Add any line that is a valid ruby comment,
        # but clear as soon as we hit a non comment line.
        if (line =~ /^\s*#/) || (line =~ /^\s*$/)
          buffer << line.lstrip
        else
          buffer.replace("")
        end
      end

      buffer
    end

    # FIXME: this method is also found in Pry::Method
    def safe_send(obj, method, *args, &block)
      (Module === obj ? Module : Object).instance_method(method).bind(obj).call(*args, &block)
    end

    # FIXME: a variant of this method is also found in Pry::Method
    def all_from_common(mod, method_type)
      %w(public protected private).map do |visibility|
        safe_send(mod, :"#{visibility}_#{method_type}s", false).select do |method_name|
          if method_type == :method
            safe_send(mod, method_type, method_name).owner == class << mod; self; end
          else
            safe_send(mod, method_type, method_name).owner == mod
          end
        end.map do |method_name|
          Pry::Method.new(safe_send(mod, method_type, method_name), :visibility => visibility.to_sym)
        end
      end.flatten
    end

    def all_methods_for(mod)
      all_from_common(mod, :instance_method) + all_from_common(mod, :method)
    end

    def all_source_locations_by_popularity
      return @all_source_locations_by_popularity if @all_source_locations_by_popularity

      ims = all_methods_for(wrapped)

      ims.reject! do |v|
        begin
          v.alias? || v.source_location.nil?
        rescue Pry::RescuableException
          true
        end
      end

      @all_source_locations_by_popularity = ims.group_by { |v| Array(v.source_location).first }.
        sort_by { |k, v| -v.size }
    end

    def method_candidates
      @method_candidtates ||= all_source_locations_by_popularity.map do |group|
        sorted_by_lowest_line_number = group.last.sort_by(&:source_line)
        best_candidate_for_group = sorted_by_lowest_line_number.first
      end
    end

    def number_of_candidates
      method_candidates.count
    end

    def method_source_location_for_candidate(idx)
      file, line = method_candidates[idx].source_location

      if file && RbxPath.is_core_path?(file)
        file = RbxPath.convert_path_to_full(file)
      end

      [file, line]
    end

  end
end
