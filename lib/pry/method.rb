class Pry
  class Method
    include RbxMethod if defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/

    class << self
      # @param [String, nil] name The name of the method to retrieve, or `nil` to
      #   delegate to `from_binding` instead.
      # @param [Binding] target The context in which to search for the method.
      # @param [Hash] options
      # @option options [Boolean] :instance Look for an instance method if `name` doesn't
      #   contain any context.
      # @option options [Boolean] :methods Look for a bound/singleton method if `name` doesn't
      #   contain any context.
      # @return [Pry::Method, nil]
      def from_str(name, target=TOPLEVEL_BINDING, options={})
        if name.nil?
          from_binding(target)
        elsif name.to_s =~ /(\S+)\#(\S+)\Z/
          context, meth_name = $1, $2
          from_module(target.eval(context), meth_name)
        elsif name.to_s =~ /(\S+)\.(\S+)\Z/
          context, meth_name = $1, $2
          from_obj(target.eval(context), meth_name)
        elsif options[:instance]
          from_module(target.eval("self"), name)
        elsif options[:methods]
          from_obj(target.eval("self"), name)
        else
          from_str(name, target, :instance => true) or
            from_str(name, target, :methods => true)
        end
      end

      # Given a `Binding`, try to extract the `::Method` it originated from and
      # use it to instantiate a `Pry::Method`. Return `nil` if this isn't
      # possible.
      # @param [Binding] b
      # @return [Pry::Method, nil]
      def from_binding(b)
        meth_name = b.eval('__method__')
        if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
          nil
        else
          new(b.eval("method(:#{meth_name})"))
        end
      end

      # Given a `Class` or `Module` and the name of a method, try to
      # instantiate a `Pry::Method` containing the instance method of
      # that name. Return `nil` if no such method exists.
      # @param [Class, Module] klass
      # @param [String] name
      # @return [Pry::Method, nil]
      def from_class(klass, name)
        new(klass.instance_method(name)) rescue nil
      end
      alias from_module from_class

      # Given an object and the name of a method, try to instantiate
      # a `Pry::Method` containing the method of that name bound to
      # that object. Return `nil` if no such method exists.
      # @param [Object] obj
      # @param [String] name
      # @return [Pry::Method, nil]
      def from_obj(obj, name)
        new(obj.method(name)) rescue nil
      end
    end

    # @param [Method, UnboundMethod, Proc] method
    def initialize(method)
      @method = method
    end

    # Return the source code of the method, or `nil` if it's unavailable.
    # @return [String, nil]
    def source
      @source ||= case source_type
        when :c
          info = pry_doc_info
          if info and info.source
            code = strip_comments_from_c_code(info.source)
          end
        when :rbx
          strip_leading_whitespace(core_code)
        when :ruby
          if pry_method?
            code = Pry.new(:input => StringIO.new(Pry.line_buffer[source_line..-1].join), :prompt => proc {""}, :hooks => {}).r
          else
            code = @method.source
          end
          strip_leading_whitespace(code)
        end
    end

    # Return the documentation for the method, of `nil` if it's unavailable.
    # @return [String, nil]
    # @raise [CommandError] Raises when the method was defined in the REPL.
    def doc
      @doc ||= case source_type
        when :c
          info = pry_doc_info
          info.docstring if info
        when :rbx
          strip_leading_hash_and_whitespace_from_ruby_comments(core_doc)
        when :ruby
          if pry_method?
            raise CommandError, "Can't view doc for a REPL-defined method."
          else
            strip_leading_hash_and_whitespace_from_ruby_comments(@method.comment)
          end
        end
    end

    # Return a `Symbol` representing the "source type" of this method. The
    # options are `:ruby` for ordinary Ruby methods, `:c` for methods
    # written in C, or `:rbx` for Rubinius core methods written in Ruby.
    # @return [Symbol]
    def source_type
      if defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/
        if core? then :rbx else :ruby end
      else
        if source_location.nil? then :c else :ruby end
      end
    end

    # Return the name of the file the method is defined in, or `nil` if
    # the filename is unavailable.
    # @return [String, nil]
    def source_file
      source_location.nil? ? nil : source_location.first
    end

    # Return the line of code in `source_file` which begins the definition
    # of the method, or `nil` if that information is unavailable.
    # @return [Fixnum, nil]
    def source_line
      source_location.nil? ? nil : source_location.last
    end

    # Return a `Symbol` representing the visibility of the method. The
    # options are `:public`, `:protected`, or `:private`.
    def visibility
      if owner.public_instance_methods.include?(name)
        :public
      elsif owner.protected_instance_methods.include?(name)
        :protected
      elsif owner.private_instance_methods.include?(name)
        :private
      else
        :none
      end
    end

    # Return a representation of the method's signature, including its
    # name and parameters. Optional and "rest" parameters are marked with `*`
    # and block parameters with `&`. If the parameter names are unavailable,
    # they're given numbered names instead.
    # Paraphrased from `awesome_print` gem.
    # @return [String]
    def signature
      if respond_to?(:parameters)
        args = parameters.inject([]) do |arr, (type, name)|
          name ||= (type == :block ? 'block' : "arg#{arr.size + 1}")
          arr << case type
                 when :req        then name.to_s
                 when :opt, :rest then "*#{name}"
                 when :block      then "&#{name}"
                 else '?'
                 end
        end
      else
        args = (1..arity.abs).map { |i| "arg#{i}" }
        args[-1] = "*#{args[-1]}" if arity < 0
      end

      "#{name}(#{args.join(', ')})"
    end

    # @return [Boolean]
    def dynamically_defined?
      source_file ? !!(source_file =~ /(\(.*\))|<.*>/) : nil
    end

    # @return [Boolean]
    def pry_method?
      source_file == Pry.eval_path
    end

    # @return [Boolean]
    def ==(obj)
      if obj.is_a? Pry::Method
        super
      else
        @method == obj
      end
    end

    # @param [Class] klass
    # @return [Boolean]
    def is_a?(klass)
      klass == Pry::Method or @method.is_a?(klass)
    end
    alias kind_of? is_a?

    # @param [String, Symbol] method_name
    # @return [Boolean]
    def respond_to?(method_name)
      super or @method.respond_to?(method_name)
    end

    def method_missing(method_name, *args, &block)
      @method.send(method_name, *args, &block)
    end

    private
      # @return [YARD::CodeObjects::MethodObject]
      # @raise [CommandError] Raises when the method can't be found or `pry-doc` isn't installed.
      def pry_doc_info
        if Pry.config.has_pry_doc
          Pry::MethodInfo.info_for(@method) or raise CommandError, "Cannot find C method: #{name}."
        else
          raise CommandError, "Cannot locate this method: #{name}. Try `gem install pry-doc` to get access to Ruby Core documentation."
        end
      end

      # @param [String] code
      # @return [String]
      def strip_comments_from_c_code(code)
        code.sub(/\A\s*\/\*.*?\*\/\s*/m, '')
      end

      # @param [String] comment
      # @return [String]
      def strip_leading_hash_and_whitespace_from_ruby_comments(comment)
        comment = comment.dup
        comment.gsub!(/\A\#+?$/, '')
        comment.gsub!(/^\s*#/, '')
        strip_leading_whitespace(comment)
      end

      # @param [String] text
      # @return [String]
      def strip_leading_whitespace(text)
        Pry::Helpers::CommandHelpers.unindent(text)
      end
  end
end
