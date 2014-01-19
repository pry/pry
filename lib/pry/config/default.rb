class Pry::Config::Default < Pry::Config
  state = {
    :input                  => proc { Readline },
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
    :collision_warning      => proc { true },
    :output_prefix          => proc { "=> "},
    :requires               => proc { [] },
    :should_load_requires   => proc { true },
    :should_load_plugins    => proc { true },
    :control_d_handler      => proc { Pry::DEFAULT_CONTROL_D_HANDLER },
    :memory_size            => proc { 100 },
    :extra_sticky_locals    => proc { {} },
    :sticky_locals          => proc { |pry|
      { _in_: pry.input_array,
        _out_: pry.output_array,
        _pry_: pry,
        _ex_: pry.last_exception,
        _file_: pry.last_file,
        _dir_: pry.last_dir,
        _: pry.last_result,
        __: pry.output_array[-2]
      }
    },
    :completer => proc {
      if defined?(Bond) && Readline::VERSION !~ /editline/i
        Pry::BondCompleter.start
      else
        Pry::InputCompleter.start
      end
    }
  }

  def initialize(*)
    super(nil)
  end

  state.each { |key, value| define_method(key, &value) }
end
