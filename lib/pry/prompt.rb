class Pry
  class Prompt
    DEFAULT_NAME = 'pry'.freeze

    SAFE_CONTEXTS = [String, Numeric, Symbol, nil, true, false].freeze

    # @return [String]
    DEFAULT_TEMPLATE =
      "[%<in_count>s] %<name>s(%<context>s)%<nesting>s%<separator>s ".freeze

    # The default Pry prompt, which includes the context and nesting level.
    # @return [Array<Proc>]
    DEFAULT = [
      proc { |context, nesting, _pry_|
        format(
          DEFAULT_TEMPLATE,
          in_count: _pry_.input_ring.count,
          name: _pry_.config.prompt_name,
          context: Pry.view_clip(context),
          nesting: (nesting > 0 ? ":#{nesting}" : ''),
          separator: '>'
        )
      },
      proc { |context, nesting, _pry_|
        format(
          DEFAULT_TEMPLATE,
          in_count: _pry_.input_ring.count,
          name: _pry_.config.prompt_name,
          context: Pry.view_clip(context),
          nesting: (nesting > 0 ? ":#{nesting}" : ''),
          separator: '*'
        )
      }
    ].freeze

    # Simple prompt doesn't display target or nesting level.
    # @return [Array<Proc>]
    SIMPLE = [proc { '>> ' }, proc { ' | ' }].freeze

    # @return [Array<Proc>]
    NO_PROMPT = Array.new(2) { proc { '' } }.freeze

    SHELL_TEMPLATE = "%<name>s %<context>s:%<pwd>s %<separator>s ".freeze

    SHELL = [
      proc do |context, _nesting, _pry_|
        format(
          SHELL_TEMPLATE,
          name: _pry_.config.prompt_name,
          context: Pry.view_clip(context),
          pwd: Dir.pwd,
          separator: '$'
        )
      end,
      proc do |context, _nesting, _pry_|
        format(
          SHELL_TEMPLATE,
          name: _pry_.config.prompt_name,
          context: Pry.view_clip(context),
          pwd: Dir.pwd,
          separator: '*'
        )
      end
    ].freeze

    NAV_TEMPLATE = "[%<in_count>s] (%<name>s) %<tree>s: %<stack_size>s> ".freeze

    # A prompt that includes the full object path as well as
    # input/output (_in_ and _out_) information. Good for navigation.
    NAV = Array.new(2) do
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
    end.freeze

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
