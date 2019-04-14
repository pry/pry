class Pry
  # The Pry config.
  # @api public
  class Config < Pry::BasicObject
    include Behavior

    # @return [Pry::Config]
    #   An object who implements the default configuration for all
    #   Pry sessions.
    def self.defaults
      defaults = from_hash(
        input: Pry.lazy { lazy_readline(defaults) },
        output: $stdout.tap { |out| out.sync = true },
        commands: Pry::Commands,
        prompt_name: Pry::Prompt::DEFAULT_NAME,
        prompt: Pry::Prompt[:default],
        prompt_safe_contexts: Pry::Prompt::SAFE_CONTEXTS,
        print: Pry::ColorPrinter.method(:default),
        quiet: false,
        exception_handler: Pry::ExceptionHandler.method(:handle_exception),
        unrescued_exceptions: [
          ::SystemExit, ::SignalException, Pry::TooSafeException
        ],

        exception_whitelist: Pry.lazy do
          defaults.output.puts(
            '[warning] Pry.config.exception_whitelist is deprecated, ' \
            'please use Pry.config.unrescued_exceptions instead.'
          )
          [::SystemExit, ::SignalException, Pry::TooSafeException]
        end,

        # The default hooks - display messages when beginning and ending Pry
        # sessions.
        hooks: Pry::Hooks.default,
        pager: true,
        system: Pry::SystemCommandHandler.method(:default),
        color: Pry::Helpers::BaseHelpers.use_ansi_codes?,
        default_window_size: 5,
        editor: Pry::Editor.default,
        should_load_rc: true,
        should_load_local_rc: true,
        should_trap_interrupts: Pry::Helpers::Platform.jruby?,
        disable_auto_reload: false,
        command_prefix: "",
        auto_indent: Pry::Helpers::BaseHelpers.use_ansi_codes?,
        correct_indent: true,
        collision_warning: false,
        output_prefix: "=> ",
        requires: [],
        should_load_requires: true,
        should_load_plugins: true,
        windows_console_warning: true,

        # Deal with the ^D key being pressed. Different behaviour in different
        # cases:
        #   1. In an expression behave like `!` command.
        #   2. At top-level session behave like `exit` command.
        #   3. In a nested session behave like `cd ..`.
        control_d_handler: proc do |eval_string, pry_instance|
          if !eval_string.empty?
            eval_string.replace('') # Clear input buffer.
          elsif pry_instance.binding_stack.one?
            pry_instance.binding_stack.clear
            throw(:breakout)
          else
            # Otherwise, saves current binding stack as old stack and pops last
            # binding out of binding stack (the old stack still has that binding).
            pry_instance.command_state["cd"] ||= Pry::Config.from_hash({})
            pry_instance.command_state['cd'].old_stack = pry_instance.binding_stack.dup
            pry_instance.binding_stack.pop
          end
        end,

        memory_size: 100,
        extra_sticky_locals: {},
        command_completions: proc { defaults.commands.keys },
        file_completions: proc { Dir["."] },
        ls: Pry::Config.from_hash(Pry::Command::Ls::DEFAULT_OPTIONS),
        completer: Pry::InputCompleter,
        history: {
          should_save: true,
          should_load: true,
          file: Pry::History.default_file
        },
        exec_string: ""
      )
    end

    def self.shortcuts
      Convenience::SHORTCUTS
    end

    # @api private
    def self.lazy_readline(defaults)
      require 'readline'
      ::Readline
    rescue LoadError
      defaults.output.puts(
        "Sorry, you can't use Pry without Readline or a compatible library. \n" \
        "Possible solutions: \n" \
        " * Rebuild Ruby with Readline support using `--with-readline` \n" \
        " * Use the rb-readline gem, which is a pure-Ruby port of Readline \n" \
        " * Use the pry-coolline gem, a pure-ruby alternative to Readline"
      )
      raise
    end
    private_class_method :lazy_readline
  end
end
