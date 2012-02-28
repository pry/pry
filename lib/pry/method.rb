# -*- coding: utf-8 -*-
class Pry
  class << self
    # If the given object is a `Pry::Method`, return it unaltered. If it's
    # anything else, return it wrapped in a `Pry::Method` instance.
    def Method(obj)
      if obj.is_a? Pry::Method
        obj
      else
        Pry::Method.new(obj)
      end
    end
  end

  class Method
    include RbxMethod if Helpers::BaseHelpers.rbx?

    class << self
      # Given a string representing a method name and optionally a binding to
      # search in, find and return the requested method wrapped in a `Pry::Method`
      # instance.
      #
      # @param [String, nil] name The name of the method to retrieve, or `nil` to
      #   delegate to `from_binding` instead.
      # @param [Binding] target The context in which to search for the method.
      # @param [Hash] options
      # @option options [Boolean] :instance Look for an instance method if `name` doesn't
      #   contain any context.
      # @option options [Boolean] :methods Look for a bound/singleton method if `name` doesn't
      #   contain any context.
      # @return [Pry::Method, nil] A `Pry::Method` instance containing the requested
      #   method, or `nil` if no method could be located matching the parameters.
      def from_str(name, target=TOPLEVEL_BINDING, options={})
        if name.nil?
          from_binding(target)
        elsif name.to_s =~ /(.+)\#(\S+)\Z/
          context, meth_name = $1, $2
          from_module(target.eval(context), meth_name)
        elsif name.to_s =~ /(.+)\.(\S+)\Z/
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
      #
      # @param [Binding] b
      # @return [Pry::Method, nil]
      #
      def from_binding(b)
        meth_name = b.eval('__method__')
        if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
          nil
        else
          method = begin
                     new(b.eval("method(#{meth_name.to_s.inspect})"))
                   rescue NameError, NoMethodError
                     Disowned.new(b.eval('self'), meth_name.to_s)
                   end

          # it's possible in some cases that the method we find by this approach is a sub-method of
          # the one we're currently in, consider:
          #
          # class A; def b; binding.pry; end; end
          # class B < A; def b; super; end; end
          #
          # Given that we can normally find the source_range of methods, and that we know which
          # __FILE__ and __LINE__ the binding is at, we can hope to disambiguate these cases.
          #
          # This obviously won't work if the source is unavaiable for some reason, or if both
          # methods have the same __FILE__ and __LINE__, or if we're in rbx where b.eval('__LINE__')
          # is broken.
          #
          guess = method

          while guess
            # needs rescue if this is a Disowned method or a C method or something...
            # TODO: Fix up the exception handling so we don't need a bare rescue
            if (guess.source_file && guess.source_range rescue false) &&
                File.expand_path(guess.source_file) == File.expand_path(b.eval('__FILE__')) &&
                guess.source_range.include?(b.eval('__LINE__'))
              return guess
            else
              guess = guess.super
            end
          end

          # Uhoh... none of the methods in the chain had the right __FILE__ and __LINE__
          # This may be caused by rbx https://github.com/rubinius/rubinius/issues/953,
          # or other unknown circumstances (TODO: we should warn the user when this happens)
          method
        end
      end

      # Given a `Class` or `Module` and the name of a method, try to
      # instantiate a `Pry::Method` containing the instance method of
      # that name. Return `nil` if no such method exists.
      #
      # @param [Class, Module] klass
      # @param [String] name
      # @return [Pry::Method, nil]
      def from_class(klass, name)
        new(safe_send(klass, :instance_method, name)) rescue nil
      end
      alias from_module from_class

      # Given an object and the name of a method, try to instantiate
      # a `Pry::Method` containing the method of that name bound to
      # that object. Return `nil` if no such method exists.
      #
      # @param [Object] obj
      # @param [String] name
      # @return [Pry::Method, nil]
      def from_obj(obj, name)
        new(safe_send(obj, :method, name)) rescue nil
      end

      # Get all of the instance methods of a `Class` or `Module`
      # @param [Class,Module] klass
      # @return [Array[Pry::Method]]
      def all_from_class(klass)
        all_from_common(klass, :instance_method)
      end

      # Get all of the methods on an `Object`
      # @param [Object] obj
      # @return [Array[Pry::Method]]
      def all_from_obj(obj)
        all_from_common(obj, :method)
      end

      # Get every `Class` and `Module`, in order, that will be checked when looking
      # for an instance method to call on this object.
      # @param [Object] obj
      # @return [Array[Class, Module]]
      def resolution_order(obj)
        if Class === obj
          singleton_class_resolution_order(obj) + instance_resolution_order(Class)
        else
          klass = singleton_class(obj) rescue obj.class
          instance_resolution_order(klass)
        end
      end

      # Get every `Class` and `Module`, in order, that will be checked when looking
      # for methods on instances of the given `Class` or `Module`.
      # This does not treat singleton classes of classes specially.
      # @param [Class, Module] klass
      # @return [Array[Class, Module]]
      def instance_resolution_order(klass)
        # include klass in case it is a singleton class,
        ([klass] + klass.ancestors).uniq
      end

      private

      # See all_from_class and all_from_obj.
      # If method_type is :instance_method, obj must be a `Class` or a `Module`
      # If method_type is :method, obj can be any `Object`
      #
      # N.B. we pre-cache the visibility here to avoid O(N²) behaviour in "ls".
      def all_from_common(obj, method_type)
        %w(public protected private).map do |visibility|
          safe_send(obj, :"#{visibility}_#{method_type}s").map do |method_name|
            new(safe_send(obj, method_type, method_name), :visibility => visibility.to_sym)
          end
        end.flatten(1)
      end

      # Acts like send but ignores any methods defined below Object or Class in the
      # inheritance hierarchy.
      # This is required to introspect methods on objects like Net::HTTP::Get that
      # have overridden the `method` method.
      def safe_send(obj, method, *args, &block)
        (Module === obj ? Module : Object).instance_method(method).bind(obj).call(*args, &block)
      end

      # Get the singleton classes of superclasses that could define methods on
      # the given class object, and any modules they include.
      # If a module is included at multiple points in the ancestry, only
      # the lowest copy will be returned.
      def singleton_class_resolution_order(klass)
        resolution_order = klass.ancestors.map do |anc|
          [singleton_class(anc)] + singleton_class(anc).included_modules if anc.is_a?(Class)
        end.compact.flatten(1)

        resolution_order.reverse.uniq.reverse - Class.included_modules
      end

      def singleton_class(obj); class << obj; self; end end
    end

    # A new instance of `Pry::Method` wrapping the given `::Method`, `UnboundMethod`, or `Proc`.
    #
    # @param [::Method, UnboundMethod, Proc] method
    # @param [Hash] known_info, can be used to pre-cache expensive to compute stuff.
    # @return [Pry::Method]
    def initialize(method, known_info={})
      @method = method
      @visibility = known_info[:visibility]
    end

    # Get the name of the method as a String, regardless of the underlying Method#name type.
    # @return [String]
    def name
      @method.name.to_s
    end

    # Get the owner of the method as a Pry::Module
    # @return [Pry::Module]
    def wrapped_owner
      @wrapped_owner ||= Pry::WrappedModule.new(owner)
    end

    # Is the method undefined? (aka `Disowned`)
    # @return [Boolean] false
    def undefined?
      false
    end

    # Get the name of the method including the class on which it was defined.
    # @example
    #   method(:puts).method_name
    #   => "Kernel.puts"
    # @return [String]
    def name_with_owner
      "#{wrapped_owner.method_prefix}#{name}"
    end

    # @return [String, nil] The source code of the method, or `nil` if it's unavailable.
    def source
      @source ||= case source_type
        when :c
          info = pry_doc_info
          if info and info.source
            code = strip_comments_from_c_code(info.source)
          end
        when :ruby
          if Helpers::BaseHelpers.rbx? && core?
            code = core_code
          elsif pry_method?
            code = Pry.new(:input => StringIO.new(Pry.line_buffer[source_line..-1].join), :prompt => proc {""}, :hooks => Pry::Hooks.new).r
          else
            code = @method.source
          end
          strip_leading_whitespace(code)
        end
    end

    # @return [String, nil] The documentation for the method, or `nil` if it's
    #   unavailable.
    # @raise [CommandError] Raises when the method was defined in the REPL.
    def doc
      @doc ||= case source_type
        when :c
          info = pry_doc_info
          info.docstring if info
        when :ruby
          if Helpers::BaseHelpers.rbx? && core?
            strip_leading_hash_and_whitespace_from_ruby_comments(core_doc)
          elsif pry_method?
            raise CommandError, "Can't view doc for a REPL-defined method."
          else
            strip_leading_hash_and_whitespace_from_ruby_comments(@method.comment)
          end
        end
    end

    # @return [Symbol] The source type of the method. The options are
    #   `:ruby` for Ruby methods or `:c` for methods written in C.
    def source_type
      source_location.nil? ? :c : :ruby
    end

    # @return [String, nil] The name of the file the method is defined in, or
    #   `nil` if the filename is unavailable.
    def source_file
      if source_location.nil?
        if !Helpers::BaseHelpers.rbx? and source_type == :c
          info = pry_doc_info
          info.file if info
        end
      else
        source_location.first
      end
    end

    # @return [Fixnum, nil] The line of code in `source_file` which begins
    #   the method's definition, or `nil` if that information is unavailable.
    def source_line
      source_location.nil? ? nil : source_location.last
    end

    # @return [Range, nil] The range of lines in `source_file` which contain
    #    the method's definition, or `nil` if that information is unavailable.
    def source_range
      source_location.nil? ? nil : (source_line)...(source_line + source.lines.count)
    end

    # @return [Symbol] The visibility of the method. May be `:public`,
    #   `:protected`, or `:private`.
    def visibility
     @visibility ||= if owner.public_instance_methods.any? { |m| m.to_s == name }
                       :public
                     elsif owner.protected_instance_methods.any? { |m| m.to_s == name }
                       :protected
                     elsif owner.private_instance_methods.any? { |m| m.to_s == name }
                       :private
                     else
                       :none
                     end
    end

    # @return [String] A representation of the method's signature, including its
    #   name and parameters. Optional and "rest" parameters are marked with `*`
    #   and block parameters with `&`. If the parameter names are unavailable,
    #   they're given numbered names instead.
    #   Paraphrased from `awesome_print` gem.
    def signature
      if respond_to?(:parameters)
        args = parameters.inject([]) do |arr, (type, name)|
          name ||= (type == :block ? 'block' : "arg#{arr.size + 1}")
          arr << case type
                 when :req   then name.to_s
                 when :opt   then "#{name}=?"
                 when :rest  then "*#{name}"
                 when :block then "&#{name}"
                 else '?'
                 end
        end
      else
        args = (1..arity.abs).map { |i| "arg#{i}" }
        args[-1] = "*#{args[-1]}" if arity < 0
      end

      "#{name}(#{args.join(', ')})"
    end

    # @return [Pry::Method, nil] The wrapped method that is called when you
    #   use "super" in the body of this method.
    def super(times=1)
      if UnboundMethod === @method
        sup = super_using_ancestors(Pry::Method.instance_resolution_order(owner), times)
      else
        sup = super_using_ancestors(Pry::Method.resolution_order(receiver), times)
        sup &&= sup.bind(receiver)
      end
      Pry::Method.new(sup) if sup
    end

    # @return [String, nil] The original name the method was defined under,
    #   before any aliasing, or `nil` if it can't be determined.
    def original_name
      return nil if source_type != :ruby
      method_name_from_first_line(source.lines.first)
    end

    # @return [Boolean] Was the method defined outside a source file?
    def dynamically_defined?
      !!(source_file and source_file =~ /(\(.*\))|<.*>/)
    end

    # @return [Boolean] Was the method defined within the Pry REPL?
    def pry_method?
      source_file == Pry.eval_path
    end

    # @return [Boolean] Is the method definitely an alias?
    def alias?
      name != original_name
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

    # Delegate any unknown calls to the wrapped method.
    def method_missing(method_name, *args, &block)
      @method.send(method_name, *args, &block)
    end

    private
      # @return [YARD::CodeObjects::MethodObject]
      # @raise [CommandError] Raises when the method can't be found or `pry-doc` isn't installed.
      def pry_doc_info
        if Pry.config.has_pry_doc
          Pry::MethodInfo.info_for(@method) or raise CommandError, "Cannot locate this method: #{name}."
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

      # @param [Class,Module] the ancestors to investigate
      # @return [Method] the unwrapped super-method
      def super_using_ancestors(ancestors, times=1)
        next_owner = self.owner
        times.times do
          i = ancestors.index(next_owner) + 1
          while ancestors[i] && !(ancestors[i].method_defined?(name) || ancestors[i].private_method_defined?(name))
            i += 1
          end
          next_owner = ancestors[i] or return nil
        end
        next_owner.instance_method(name) rescue nil
      end

      # @param [String] first_ln The first line of a method definition.
      # @return [String, nil]
      def method_name_from_first_line(first_ln)
        return nil if first_ln.strip !~ /^def /

        tokens = CodeRay.scan(first_ln, :ruby)
        tokens = tokens.tokens.each_slice(2) if tokens.respond_to?(:tokens)
        tokens.each_cons(2) do |t1, t2|
          if t2.last == :method || t2.last == :ident && t1 == [".", :operator]
            return t2.first
          end
        end

        nil
      end

    # A Disowned Method is one that's been removed from the class on which it was defined.
    #
    # e.g.
    # class C
    #   def foo
    #     C.send(:undefine_method, :foo)
    #     Pry::Method.from_binding(binding)
    #   end
    # end
    #
    # In this case we assume that the "owner" is the singleton class of the receiver.
    #
    # This occurs mainly in Sinatra applications.
    class Disowned < Method
      attr_reader :receiver, :name

      # Create a new Disowned method.
      #
      # @param [Object] receiver
      # @param [String] method_name
      def initialize(*args)
        @receiver, @name = *args
      end

      # Is the method undefined? (aka `Disowned`)
      # @return [Boolean] true
      def undefined?
        true
      end

      # Get the hypothesized owner of the method.
      #
      # @return [Object]
      def owner
        class << receiver; self; end
      end

      # Raise a more useful error message instead of trying to forward to nil.
      def method_missing(meth_name, *args, &block)
        raise "Cannot call '#{meth_name}' on an undef'd method." if method(:name).respond_to?(meth_name)
        Object.instance_method(:method_missing).bind(self).call(meth_name, *args, &block)
      end
    end
  end
end
