class Pry
  # Prompt represents the Pry prompt and holds necessary procs and constants to
  # be used with Readline-like libraries.
  #
  # @since v0.11.0
  # @api private
  module Prompt
    # @return [String]
    DEFAULT_NAME = 'pry'.freeze

    # @return [Array<Object>] the list of objects that are known to have a
    #   1-line #inspect output suitable for prompt
    SAFE_CONTEXTS = [String, Numeric, Symbol, nil, true, false].freeze

    # @return [String]
    DEFAULT_TEMPLATE =
      "[%<in_count>s] %<name>s(%<context>s)%<nesting>s%<separator>s ".freeze

    # @return [String]
    SHELL_TEMPLATE = "%<name>s %<context>s:%<pwd>s %<separator>s ".freeze

    # @return [String]
    NAV_TEMPLATE = "[%<in_count>s] (%<name>s) %<tree>s: %<stack_size>s> ".freeze

    class << self
      private

      # @return [Proc] the default prompt
      def default(separator)
        proc do |context, nesting, _pry_|
          format(
            DEFAULT_TEMPLATE,
            in_count: _pry_.input_ring.count,
            name: _pry_.config.prompt_name,
            context: Pry.view_clip(context),
            nesting: (nesting > 0 ? ":#{nesting}" : ''),
            separator: separator
          )
        end
      end

      # @return [Proc] the shell prompt
      def shell(separator)
        proc do |context, _nesting, _pry_|
          format(
            SHELL_TEMPLATE,
            name: _pry_.config.prompt_name,
            context: Pry.view_clip(context),
            pwd: Dir.pwd,
            separator: separator
          )
        end
      end

      # @return [Proc] the nav prompt
      def nav
        proc do |_context, _nesting, _pry_|
          tree = _pry_.binding_stack.map { |b| Pry.view_clip(b.eval('self')) }
          format(
            NAV_TEMPLATE,
            in_count: _pry_.input_ring.count,
            name: _pry_.config.prompt_name,
            tree: tree.join(' / '),
            stack_size: _pry_.binding_stack.size - 1
          )
        end
      end
    end

    # The default Pry prompt, which includes the context and nesting level.
    # @return [Array<Proc>]
    DEFAULT = [default('>'), default('*')].freeze

    # Simple prompt doesn't display target or nesting level.
    # @return [Array<Proc>]
    SIMPLE = [proc { '>> ' }, proc { ' | ' }].freeze

    # @return [Array<Proc>]
    NO_PROMPT = Array.new(2) { proc { '' } }.freeze

    # @return [Array<Proc>]
    SHELL = [shell('$'), shell('*')].freeze

    # A prompt that includes the full object path as well as
    # input/output (_in_ and _out_) information. Good for navigation.
    NAV = Array.new(2) { nav }.freeze

    # @return [Hash{String=>Hash}]
    MAP = {
      "default" => {
        value: DEFAULT,
        description: "The default Pry prompt. Includes information about the\n" \
                     "current expression number, evaluation context, and nesting\n" \
                     "level, plus a reminder that you're using Pry.".freeze
      },

      "simple" => {
        value: SIMPLE,
        description: "A simple '>>'.".freeze
      },

      "nav" => {
        value: NAV,
        description: "A prompt that displays the binding stack as a path and\n" \
                     "includes information about _in_ and _out_.".freeze
      },

      "none" => {
        value: NO_PROMPT,
        description: "Wave goodbye to the Pry prompt.".freeze
      }
    }.freeze
  end
end
