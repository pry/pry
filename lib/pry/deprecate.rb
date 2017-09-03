# coding: utf-8
module Pry::Deprecate
  require 'set'
  require 'monitor'
  DEPRECATE_PRY_SET = SortedSet.new []
  DEPRECATE_LOCK = Monitor.new
  DEPRECATE_QUOTED_FILE = Regexp.quote(__FILE__).freeze

  #
  # Deprecates a method so that all future calls to it display a deprecation message,
  # unless _pry_.config.print_deprecations is not 'true'.
  #
  # @example
  #
  #  deprecate_method! [Kernel.method(:puts), "StringIO#puts"],
  #                    "#puts is deprecated, use #write instead"
  #  Kernel.puts "foo"
  #  StringIO.new("").puts "bar"
  #
  # @param [Array<String, Method>] sigs
  #   An array of signatures in the form of a String as 'Foo::Bar#baz' (instance method),
  #   'Foo::Bar.baz' (class method) or Method objects.
  #
  # @param [Pry] pry
  #   An instance of Pry. `Pry#output` is used for writing.
  #   Optional, since defaults to '_pry_' in scope of current 'self'.
  #
  # @return [nil]
  #
  def deprecate_method! sigs, message, pry=((defined?(_pry_) and _pry_) or raise)
    DEPRECATE_LOCK.synchronize &proc {
      method(:__deprecate_method).call(sigs, message, pry)
    }
  end

  #
  # Similar to {#deprecate_method!} but specialised to {Pry::Config}.
  # Exists for convenience but also to implement another workaround for JRuby.
  #
  #  @param [Array<Symbol>]
  #    Array of Symbols that identify the name of each config attribute that
  #    should be deprecated.
  #
  #  @param [String] message
  #    Deprecation message.
  #
  #  @param [Pry] pry
  #    An instance of Pry. `Pry#output` is used for writing.
  #    Optional, since defaults to '_pry_' in scope of current 'self'.
  #
  #  @see
  #    See #deprecate_method!
  #
  #  @example
  #
  #    deprecate_config! [:foo], "Pry::Config#foo is deprecated, use #bar instead"
  #
  def deprecate_config! attrs, message, pry=((defined?(_pry_) and _pry_) or raise)
    DEPRECATE_LOCK.synchronize &proc {
      sigs = attrs.flat_map do |attr|
        # Bring the method into existence, for JRuby. Pry::Config lazy defines.
        # It's not required for CRuby, so JRuby is likely not being compliant
        # with Ruby (respond_to_missing? or similar) behaviour here.
        pry.config.public_send(attr) if pry.h.jruby?
        [Pry.config.method(attr), Pry.config.method(:"#{attr}="),
         pry.config.method(attr), pry.config.method(:"#{attr}=")]
      end
      method(:__deprecate_method).call(sigs, message, pry)
    }
  end

  #
  # @api private
  #
  def __deprecate_method(sigs, message, pry)
    sigs.each do |sig|
      mod, method =  String === sig ?
                       __deprecate_string_sig(sig)  : __deprecate_method_sig(sig)
      next if method.source_location.to_a[0] == __FILE__
      this = self
      mod.send :define_method, method.name do |*a, &b|
        result = (::UnboundMethod === method ? method.bind(self) : method).call(*a, &b)
        # No active Pry's? Don't acquire lock for no-op filter.
        return result if DEPRECATE_PRY_SET.empty?
        # Although '__deprecate_method' is within a lock (imposed by caller),
        # the defined method is not, only its definition is. We synchronize
        # access around 'DEPRECATE_PRY_SET here again. Note the original method
        # has been called and its return value stored in 'result' but at this point
        # we could block another thread from almost immediately returning it.
        this.const_get(:DEPRECATE_LOCK, true).synchronize do
          this.__deprecate_filter(DEPRECATE_PRY_SET).each do |pry|
            io = pry.output
            io.puts("%s %s\n%s\n" \
                    "Run 'toggle-pry-deprecations' or '_pry_.config.print_deprecations = false' to stop printing this message.\n\n" %
                    [
                      pry.h.bright_white_on_red(" DEPRECATED "),
                      message,
                      ".. Called from #{this.__deprecate_walk_back_to_caller(caller)}"
                    ]
                   ) if not io.closed?
          end
        end
        result
      end
    end
    DEPRECATE_PRY_SET.add(pry)
    __deprecate_gc_hook(pry)
    nil
  end

  def __deprecate_yay_bad_tests
    DEPRECATE_PRY_SET.clear
  end

  #
  # @api private
  #
  def __deprecate_walk_back_to_caller(ary)
    sees = 0
    ary.find do |line|
      sees += 1 if line =~ /#{DEPRECATE_QUOTED_FILE}/
      # After DEPRECATE_QUOTED_FILE has been seen twice, the next line
      # that doesn't match is the caller.
      sees == 2 and line !~ /#{DEPRECATE_QUOTED_FILE}/
    end
  end

  #
  # @api private
  #
  def __deprecate_filter(prys)
    SortedSet.new prys.select {|pry|
      next false if pry.config.print_deprecations != true
      lpry = prys.each.to_a.last
      next false if pry != lpry and pry.output == lpry.output and lpry.config.print_deprecations != true
      true
    }
  end

  #
  # @api private
  #
  def __deprecate_gc_hook(pry)
    # Why hooks with the same name & "callable" don't stack....?
    # Or no-op instead of raise error?
    if not pry.hooks.hook_exists? :after_session, "#{pry.hash}-deprecate_method!"
      pry.hooks.add_hook(:after_session, "#{pry.hash}-deprecate_method!") {
        DEPRECATE_LOCK.synchronize { DEPRECATE_PRY_SET.delete(pry) }
      }
    end
  end

  #
  # @api private
  #
  def __deprecate_string_sig(s)
    path = s.split('::')
    scope = path[-1].include?('#') ? :instance : :module
    path[-1], method = path[-1].split /[.#]/, 2
    mod = path.inject(Object) { |m,s| m.const_get(s) }
    method = scope == :instance ? mod.instance_method(method) : mod.method(method)
    [scope == :instance ? mod : class<<mod; self; end, method]
  end

  #
  # @api private
  #
  def __deprecate_method_sig(m)
   [m.owner, m]
  end

  private :__deprecate_string_sig, :__deprecate_method_sig, :__deprecate_gc_hook, :__deprecate_method
  private_constant :DEPRECATE_PRY_SET, :DEPRECATE_LOCK, :DEPRECATE_QUOTED_FILE
  extend self
end
