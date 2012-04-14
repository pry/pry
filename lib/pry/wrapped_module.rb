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

    def doc
      return @doc if @doc

      file_name, line = source_location

      if file_name.nil?
        if defined?(YARD) && from_yard = YARD::Registry.at(name)
          @doc = from_yard.docstring
        else
          raise CommandError, "Can't find module's source location"
        end
      else
        @doc = extract_doc
      end

      raise CommandError, "Can't find docs for module: #{name}." if !@doc

      @doc = process_comment_markup(strip_leading_hash_and_whitespace_from_ruby_comments(@doc), :ruby)
    end

    # Retrieve the source for the module.
    def source
      return @source if @source

      file, line = source_location
      raise CommandError, "Could not locate source for #{wrapped}!" if file.nil?

      @source = strip_leading_whitespace(Pry::Code.retrieve_complete_expression_from(@host_file_lines[(line - 1)..-1]))

    end

    # Retrieve the source location of a module. Return value is in same
    # format as Method#source_location. If the source location
    # cannot be found this method returns `nil`.
    #
    # @param [Module] mod The module (or class).
    # @return [Array<String, Fixnum>] The source location of the
    #   module (or class).
    def source_location
      return @source_location if @source_location

      mod_type_string = wrapped.class.to_s.downcase
      file, line = find_module_method_source_location

      return nil if !file.is_a?(String)

      class_regex = /#{mod_type_string}\s*(\w*)(::)?#{wrapped.name.split(/::/).last}/

      if file == Pry.eval_path
        @host_file_lines ||= Pry.line_buffer.drop(1)
      else
        @host_file_lines ||= File.readlines(file)
      end

      search_lines = @host_file_lines[0..(line - 2)]
      idx = search_lines.rindex { |v| class_regex =~ v }

      @source_location = [file,  idx + 1]
    rescue Pry::RescuableException
      nil
    end

    private

    def extract_doc
      file_name, line = source_location

      buffer = ""
      @host_file_lines[0..(line - 2)].each do |line|
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

    def find_module_method_source_location
      ims = Pry::Method.all_from_class(wrapped, false) + Pry::Method.all_from_obj(wrapped, false)

      file, line = ims.each do |m|
        break m.source_location if m.source_location && !m.alias?
      end

      if file && RbxPath.is_core_path?(file)
        file = RbxPath.convert_path_to_full(file)
      end

      [file, line]
    end

    # FIXME: both methods below copied from Pry::Method
    def strip_leading_whitespace(text)
      Pry::Helpers::CommandHelpers.unindent(text)
    end

    # @param [String] comment
    # @return [String]
    def strip_leading_hash_and_whitespace_from_ruby_comments(comment)
      comment = comment.dup
      comment.gsub!(/\A\#+?$/, '')
      comment.gsub!(/^\s*#/, '')
      strip_leading_whitespace(comment)
    end

  end
end
