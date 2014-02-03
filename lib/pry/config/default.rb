class Pry::Config::Default
  include Pry::Config::Behavior

  default = {
    :input                  => proc { lazy_readline },
    :output                 => proc { $stdout },
    :commands               => proc { Pry::Commands },
    :prompt_name            => proc { Pry::DEFAULT_PROMPT_NAME },
    :prompt                 => proc { Pry::DEFAULT_PROMPT },
    :prompt_safe_objects    => proc { Pry::DEFAULT_PROMPT_SAFE_OBJECTS },
    :print                  => proc { Pry::DEFAULT_PRINT },
    :quiet                  => proc { false },
    :exception_handler      => proc { Pry::DEFAULT_EXCEPTION_HANDLER },
    :exception_whitelist    => proc { Pry::DEFAULT_EXCEPTION_WHITELIST },
    :hooks                  => proc { Pry::DEFAULT_HOOKS },
    :pager                  => proc { true },
    :system                 => proc { Pry::DEFAULT_SYSTEM },
    :color                  => proc { Pry::Helpers::BaseHelpers.use_ansi_codes? },
    :default_window_size    => proc { 5 },
    :editor                 => proc { Pry.default_editor_for_platform }, # TODO: Pry::Platform.editor
    :should_load_rc         => proc { true },
    :should_load_local_rc   => proc { true },
    :should_trap_interrupts => proc { Pry::Helpers::BaseHelpers.jruby? }, # TODO: Pry::Platform.jruby?
    :disable_auto_reload    => proc { false },
    :command_prefix         => proc { "" },
    :auto_indent            => proc { Pry::Helpers::BaseHelpers.use_ansi_codes? },
    :correct_indent         => proc { true },
    :collision_warning      => proc { false },
    :output_prefix          => proc { "=> "},
    :requires               => proc { [] },
    :should_load_requires   => proc { true },
    :should_load_plugins    => proc { true },
    :control_d_handler      => proc { Pry::DEFAULT_CONTROL_D_HANDLER },
    :memory_size            => proc { 100 },
    :extra_sticky_locals    => proc { {} },
    :command_completions    => proc { proc { Pry.commands.commands.keys } },
    :file_completions       => proc { proc { Dir["."] } },
    :completer              => proc { lazy_completer }
  }

  def initialize
    super(nil)
    configure_ls
    configure_gist
    configure_history
  end

  default.each do |key, value|
    define_method(key) do
      if default[key].equal?(value)
        default[key] = instance_eval(&value)
      end
      default[key]
    end
  end

private

  # TODO:
  # all of this configure_* stuff is a relic of old code.
  # we should try move this code to being command-local.
  def configure_ls
    self["ls"] = Pry::Config.from_hash({
      :heading_color            => :bright_blue,
      :public_method_color      => :default,
      :private_method_color     => :blue,
      :protected_method_color   => :blue,
      :method_missing_color     => :bright_red,
      :local_var_color          => :yellow,
      :pry_var_color            => :default,     # e.g. _, _pry_, _file_
      :instance_var_color       => :blue,        # e.g. @foo
      :class_var_color          => :bright_blue, # e.g. @@foo
      :global_var_color         => :default,     # e.g. $CODERAY_DEBUG, $eventmachine_library
      :builtin_global_color     => :cyan,        # e.g. $stdin, $-w, $PID
      :pseudo_global_color      => :cyan,        # e.g. $~, $1..$9, $LAST_MATCH_INFO
      :constant_color           => :default,     # e.g. VERSION, ARGF
      :class_constant_color     => :blue,        # e.g. Object, Kernel
      :exception_constant_color => :magenta,     # e.g. Exception, RuntimeError
      :unloaded_constant_color  => :yellow,      # Any constant that is still in .autoload? state
      :separator                => "  ",
      :ceiling                  => [Object, Module, Class]
    })
  end

  def configure_gist
    self["gist"] = Pry::Config.from_hash(inspecter: proc(&:pretty_inspect))
  end

  def configure_history
    self["history"] = Pry::Config.from_hash "should_save" => true,
      "should_load" => true
    history.file = File.expand_path("~/.pry_history") rescue nil
    if history.file.nil?
      self.should_load_rc = false
      history.should_save = false
      history.should_load = false
    end
  end

  def lazy_readline
    require 'readline'
    Readline
  rescue LoadError
    warn "Sorry, you can't use Pry without Readline or a compatible library."
    warn "Possible solutions:"
    warn " * Rebuild Ruby with Readline support using `--with-readline`"
    warn " * Use the rb-readline gem, which is a pure-Ruby port of Readline"
    warn " * Use the pry-coolline gem, a pure-ruby alternative to Readline"
    raise
  end

  def lazy_completer
    if defined?(Bond) && !is_editline?(input)
      Pry::BondCompleter.start
    else
      Pry::InputCompleter.start
    end
  end

  def is_editline?(input)
    defined?(input::VERSION) && input::VERSION =~ /editline/i
  end
end
