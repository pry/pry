class Pry
  class Method
    include RbxMethod if defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/

    class << self
      def from_str(str, target=TOPLEVEL_BINDING, options={})
        if str.nil?
          from_binding(target)
        elsif str.to_s =~ /(\S+)\#(\S+)\Z/
          context, meth_name = $1, $2
          from_module(target.eval(context), meth_name)
        elsif str.to_s =~ /(\S+)\.(\S+)\Z/
          context, meth_name = $1, $2
          from_obj(target.eval(context), meth_name)
        elsif options[:instance]
          new(target.eval("instance_method(:#{str})")) rescue nil
        elsif options[:methods]
          new(target.eval("method(:#{str})")) rescue nil
        else
          from_str(str, target, :instance => true) or
            from_str(str, target, :methods => true) or
            raise CommandError, "Method #{str} could not be found."
        end
      end

      def from_binding(b)
        meth_name = b.eval('__method__')
        if [:__script__, nil, :__binding__, :__binding_impl__].include?(meth_name)
          nil
        else
          new(b.eval("method(:#{meth_name})"))
        end
      end

      def from_module(nodule, name)
        new(nodule.instance_method(name)) rescue nil
      end
      alias from_class from_module

      def from_obj(obj, name)
        new(obj.method(name)) rescue nil
      end
    end

    def initialize(method)
      @method = method
    end

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

    def source_type
      if defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/
        if core? then :rbx else :ruby end
      else
        if source_location.nil? then :c else :ruby end
      end
    end

    def source_file
      source_location.nil? ? nil : source_location.first
    end

    def source_line
      source_location.nil? ? nil : source_location.last
    end

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

    # paraphrased from awesome_print gem
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

    def dynamically_defined?
      source_file ? !!(source_file =~ /(\(.*\))|<.*>/) : nil
    end

    def pry_method?
      source_file == Pry.eval_path
    end

    def ==(obj)
      if obj.is_a? Pry::Method
        super
      else
        @method == obj
      end
    end

    def is_a?(klass)
      klass == Pry::Method or @method.is_a?(klass)
    end
    alias kind_of? is_a?

    def respond_to?(method_name)
      super or @method.respond_to?(method_name)
    end

    def method_missing(method_name, *args, &block)
      @method.send(method_name, *args, &block)
    end

    private
      def pry_doc_info
        if Pry.config.has_pry_doc
          Pry::MethodInfo.info_for(@method) or raise CommandError, "Cannot find C method: #{name}."
        else
          raise CommandError, "Cannot locate this method: #{name}. Try `gem install pry-doc` to get access to Ruby Core documentation."
        end
      end

      def strip_comments_from_c_code(code)
        code.sub(/\A\s*\/\*.*?\*\/\s*/m, '')
      end

      def strip_leading_hash_and_whitespace_from_ruby_comments(comment)
        comment = comment.dup
        comment.gsub!(/\A\#+?$/, '')
        comment.gsub!(/^\s*#/, '')
        strip_leading_whitespace(comment)
      end

      def strip_leading_whitespace(text)
        Pry::Helpers::CommandHelpers.unindent(text)
      end
  end
end
