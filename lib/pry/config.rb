class Pry
  # The Pry config.
  # @api public
  class Config < Pry::BasicObject
    include Behavior

    #
    # @return [Pry::Config]
    #   An object who implements the default configuration for all
    #   Pry sessions.
    #
    def self.defaults
      defaults = from_hash(
        input: Pry.lazy { lazy_readline(defaults) },
        output: $stdout.tap { |out| out.sync = true },
        commands: Pry::Commands,
        prompt_name: Pry::Prompt::DEFAULT_NAME,
        prompt: Pry::Prompt[:default],
        prompt_safe_contexts: Pry::Prompt::SAFE_CONTEXTS,
        print: Pry::DEFAULT_PRINT,
        quiet: false,
        exception_handler: Pry::DEFAULT_EXCEPTION_HANDLER,
        unrescued_exceptions: Pry::DEFAULT_UNRESCUED_EXCEPTIONS,
        exception_whitelist: Pry.lazy do
          defaults.output.puts(
            '[warning] Pry.config.exception_whitelist is deprecated, ' \
            'please use Pry.config.unrescued_exceptions instead.'
          )
          Pry::DEFAULT_UNRESCUED_EXCEPTIONS
        end,

        # The default hooks - display messages when beginning and ending Pry
        # sessions.
        hooks: Pry::Hooks.new.add_hook(
          :before_session, :default
        ) do |_out, _target, _pry_|
          next if _pry_.quiet?

          _pry_.run_command('whereami --quiet')
        end,

        pager: true,
        system: Pry::DEFAULT_SYSTEM,
        color: Pry::Helpers::BaseHelpers.use_ansi_codes?,
        default_window_size: 5,
        editor: Pry.default_editor_for_platform,
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
        control_d_handler: Pry::DEFAULT_CONTROL_D_HANDLER,
        memory_size: 100,
        extra_sticky_locals: {},
        command_completions: proc { defaults.commands.keys },
        file_completions: proc { Dir["."] },
        ls: Pry::Config.from_hash(Pry::Command::Ls::DEFAULT_OPTIONS),
        completer: Pry::InputCompleter,
        gist: Pry::Config.from_hash(inspecter: proc(&:pretty_inspect)),
        history: Pry::Config.from_hash(
          should_save: true, should_load: true
        ).tap do |history|
          history_file =
            if File.exist?(File.expand_path('~/.pry_history'))
              '~/.pry_history'
            elsif ENV.key?('XDG_DATA_HOME') && ENV['XDG_DATA_HOME'] != ''
              # See XDG Base Directory Specification at
              # https://standards.freedesktop.org/basedir-spec/basedir-spec-0.8.html
              ENV['XDG_DATA_HOME'] + '/pry/pry_history'
            else
              '~/.local/share/pry/pry_history'
            end
          history.file = File.expand_path(history_file)
        end,
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
