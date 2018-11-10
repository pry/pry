class Pry
  # Prompt represents the Pry prompt, which can be used with Readline-like
  # libraries. It defines a few default prompts (default prompt, simple prompt,
  # etc) and also provides an API to add custom prompts.
  #
  # @example
  #   Pry::Prompt.add(
  #     :ipython,
  #     'IPython-like prompt', [':', '...:']
  #   ) do |_context, _nesting, _pry_, sep|
  #     sep == ':' ? "In [#{_pry_.input_ring.count}]: " : '   ...: '
  #   end
  #
  #   # Produces:
  #   # In [3]: def foo
  #   #    ...:   puts 'foo'
  #   #    ...: end
  #   # => :foo
  #   # In [4]:
  # @since v0.11.0
  # @api public
  module Prompt
    # @return [String]
    DEFAULT_NAME = 'pry'.freeze

    # @return [Array<Object>] the list of objects that are known to have a
    #   1-line #inspect output suitable for prompt
    SAFE_CONTEXTS = [String, Numeric, Symbol, nil, true, false].freeze

    # @deprecated Use {Pry::Prompt.add} instead.
    MAP = {}
    deprecate_constant(:MAP) if respond_to?(:deprecate_constant)

    # A Hash that holds all prompts. The keys of the Hash are prompt
    # names, the values are Hash instances of the format {:description, :value}.
    @prompts = {}

    # The name of the current default prompt.
    @default_prompt = 'default'

    class << self
      #
      # @return [Hash]
      #   Returns the current default prompt as a Hash.
      #
      def default_prompt
        self[@default_prompt]
      end

      #
      # Sets the default prompt that will be used when a Pry session starts.
      # It can be used from inside a `.pryrc` file.
      #
      # @example
      #   Pry::Prompt.select_default 'simple'
      #   Pry::Prompt.select_default 'nav'
      #   Pry::Prompt.select_default 'rails' # when using pry-rails
      #
      # @raise [ArgumentError]
      #   When the prompt is not known to Pry.
      #
      # @param [String] prompt_name
      #   The name of a prompt.
      #
      # @return [void]
      #
      # @api public
      #
      def select_default(prompt_name)
        if self[prompt_name]
          @default_prompt = prompt_name
          nil
        else
          raise ArgumentError, "'#{prompt_name}' is not known to Pry."
        end
      end

      #
      # @example
      #   Pry::Prompt.prompt_object? Pry::Prompt[:nav] # => true
      #   Pry::Prompt.prompt_object? 'foobar' # => false
      #
      # @param [Object] obj
      #
      # @return [Boolean]
      #   Returns true when 'obj' is an object created by the {Pry::Prompt.add} method.
      #
      def prompt_object?(obj)
        obj.respond_to?(:keys) and obj.keys == [:description, :value]
      end

      # Retrieves a prompt.
      #
      # @example
      #   Prompt[:my_prompt][:value]
      #
      # @param [Symbol] prompt_name The name of the prompt you want to access
      # @return [Hash{Symbol=>Object}]
      # @since v0.12.0
      def [](prompt_name)
        all[prompt_name.to_s]
      end

      # @return [Hash{Symbol=>Hash}] the duplicate of the internal prompts hash
      # @note Use this for read-only operations
      # @since v0.12.0
      def all
        @prompts.dup
      end

      # Adds a new prompt to the prompt hash.
      #
      # @param [Symbol] prompt_name
      # @param [String] description
      # @param [Array<String>] separators The separators to differentiate
      #   between prompt modes (default mode and class/method definition mode).
      #   The Array *must* have a size of 2.
      # @yield [context, nesting, _pry_, sep]
      # @yieldparam context [Object] the context where Pry is currently in
      # @yieldparam nesting [Integer] whether the context is nested
      # @yieldparam _pry_ [Pry] the Pry instance
      # @yieldparam separator [String] separator string
      # @return [nil]
      # @raise [ArgumentError] if the size of `separators` is not 2
      # @since v0.12.0
      def add(prompt_name, description = '', separators = %w[> *])
        unless separators.size == 2
          raise ArgumentError, "separators size must be 2, given #{separators.size}"
        end

        @prompts[prompt_name.to_s] = {
          description: description,
          value: separators.map do |sep|
            proc { |context, nesting, _pry_| yield(context, nesting, _pry_, sep) }
          end
        }.freeze

        nil
      end

      private

      def prompt_name(name)
        return name unless name.is_a?(Pry::Config::Lazy)

        name.call
      end
    end

    add(:default, <<DESC) do |context, nesting, _pry_, sep|
The default Pry prompt. Includes information about the current expression
number, evaluation context, and nesting level, plus a reminder that you're
using Pry.
DESC
      format(
        "[%<in_count>s] %<name>s(%<context>s)%<nesting>s%<separator>s ",
        in_count: _pry_.input_ring.count,
        name: prompt_name(_pry_.config.prompt_name),
        context: Pry.view_clip(context),
        nesting: (nesting > 0 ? ":#{nesting}" : ''),
        separator: sep
      )
    end

    add(:simple, "A simple `>>`.\n", ['>> ', ' | ']) do |_, _, _, sep|
      sep
    end

    add(:nav, <<DESC, %w[> *]) do |context, nesting, _pry_, sep|
A prompt that displays the binding stack as a path and includes information
about #{Helpers::Text.bold('_in_')} and #{Helpers::Text.bold('_out_')}.
DESC
      tree = _pry_.binding_stack.map { |b| Pry.view_clip(b.eval('self')) }
      format(
        "[%<in_count>s] (%<name>s) %<tree>s: %<stack_size>s%<separator>s ",
        in_count: _pry_.input_ring.count,
        name: prompt_name(_pry_.config.prompt_name),
        tree: tree.join(' / '),
        stack_size: _pry_.binding_stack.size - 1,
        separator: sep
      )
    end

    add(:shell, <<DESC, %w[$ *]) do |context, nesting, _pry_, sep|
A prompt that displays `$PWD` as you change it.
DESC
      format(
        "%<name>s %<context>s:%<pwd>s %<separator>s ",
        name: prompt_name(_pry_.config.prompt_name),
        context: Pry.view_clip(context),
        pwd: Dir.pwd,
        separator: sep
      )
    end

    add(:none, 'Wave goodbye to the Pry prompt.', Array.new(2)) { '' }
  end
end
