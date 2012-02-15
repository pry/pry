require 'ostruct'
require 'forwardable'
require 'pry/config'

class Pry

  # The RC Files to load.
  RC_FILES = ["~/.pryrc", "./.pryrc"]

  # class accessors
  class << self
    extend Forwardable

    # convenience method
    def self.delegate_accessors(delagatee, *names)
      def_delegators delagatee, *names
      def_delegators delagatee, *names.map { |v| "#{v}=" }
    end

    # Get/Set the Proc that defines extra Readline completions (on top
    # of the ones defined for IRB).
    # @return [Proc] The Proc that defines extra Readline completions (on top
    # @example Add file names to completion list
    #   Pry.custom_completions = proc { Dir.entries('.') }
    attr_accessor :custom_completions

    # @return [Fixnum] The current input line.
    attr_accessor :current_line

    # @return [Array] The Array of evaluated expressions.
    attr_accessor :line_buffer

    # @return [String] The __FILE__ for the `eval()`. Should be "(pry)"
    #   by default.
    attr_accessor :eval_path

    # @return [OpenStruct] Return Pry's config object.
    attr_accessor :config

    # @return [History] Return Pry's line history object.
    attr_accessor :history

    # @return [Boolean] Whether Pry was activated from the command line.
    attr_accessor :cli

    # @return [Fixnum] The number of active Pry sessions.
    attr_accessor :active_sessions

    # plugin forwardables
    def_delegators :@plugin_manager, :plugins, :load_plugins, :locate_plugins

    delegate_accessors :@config, :input, :output, :commands, :prompt, :print, :exception_handler,
      :hooks, :color, :pager, :editor, :memory_size, :input_stack
  end

  # Load the rc files given in the `Pry::RC_FILES` array.
  # This method can also be used to reload the files if they have changed.
  def self.load_rc
    files = RC_FILES.collect { |file_name| File.expand_path(file_name) }.uniq
    files.each do |file_name|
      begin
        load(file_name) if File.exists?(file_name)
      rescue RescuableException => e
        puts "Error loading #{file_name}: #{e}"
      end
    end
  end

  # Load any Ruby files specified with the -r flag on the command line.
  def self.load_requires
    Pry.config.requires.each do |file|
      require file
    end
  end

  # Trap interrupts on jruby, and make them behave like MRI so we can
  # catch them.
  def self.load_traps
    trap('INT'){ raise Interrupt }
  end

  # Do basic setup for initial session.
  # Including: loading .pryrc, loading plugins, loading requires, and
  # loading history.
  def self.initial_session_setup

    return if !initial_session?

    # note these have to be loaded here rather than in pry_instance as
    # we only want them loaded once per entire Pry lifetime.
    load_rc if Pry.config.should_load_rc
    load_plugins if Pry.config.should_load_plugins
    load_requires if Pry.config.should_load_requires
    load_history if Pry.config.history.should_load
    load_traps if Pry.config.should_trap_interrupts

    @initial_session = false
  end

  # Start a Pry REPL.
  # This method also loads the files specified in `Pry::RC_FILES` the
  # first time it is invoked.
  # @param [Object, Binding] target The receiver of the Pry session
  # @param [Hash] options
  # @option options (see Pry#initialize)
  # @example
  #   Pry.start(Object.new, :input => MyInput.new)
  def self.start(target=TOPLEVEL_BINDING, options={})
    target = Pry.binding_for(target)
    initial_session_setup

    # create the Pry instance to manage the session
    pry_instance = new(options)

    # save backtrace
    pry_instance.backtrace = caller

    # if Pry was started via binding.pry, elide that from the backtrace.
    pry_instance.backtrace.shift if pry_instance.backtrace.first =~ /pry.*core_extensions.*pry/

    # yield the binding_stack to the hook for modification
    pry_instance.exec_hook(
                           :when_started,
                           target,
                           options,
                           pry_instance
                           )

    if !pry_instance.binding_stack.empty?
      head = pry_instance.binding_stack.pop
    else
      head = target
    end

    # Enter the matrix
    pry_instance.repl(head)
  end

  # An inspector that clips the output to `max_length` chars.
  # In case of > `max_length` chars the `#<Object...> notation is used.
  # @param obj The object to view.
  # @param max_length The maximum number of chars before clipping occurs.
  # @return [String] The string representation of `obj`.
  def self.view_clip(obj, max_length = 60)
    if obj.kind_of?(Module) && obj.name.to_s != "" && obj.name.to_s.length <= max_length
      obj.name.to_s
    elsif TOPLEVEL_BINDING.eval('self') == obj
      # special case for 'main' object :)
      obj.to_s
    elsif [String, Numeric, Symbol, nil, true, false].any? { |v| v === obj } && obj.inspect.length <= max_length
      obj.inspect
    else
      "#<#{obj.class}>"#:%x>"# % (obj.object_id << 1)
    end

  rescue RescuableException
    "unknown"
  end

  # Load Readline history if required.
  def self.load_history
    Pry.history.load
  end

  # Save new lines of Readline history if required.
  def self.save_history
    Pry.history.save
  end

  # @return [Boolean] Whether this is the first time a Pry session has
  #   been started since loading the Pry class.
  def self.initial_session?
    @initial_session
  end

  # Run a Pry command from outside a session. The commands available are
  # those referenced by `Pry.commands` (the default command set).
  # @param [String] arg_string The Pry command (including arguments,
  #   if any).
  # @param [Hash] options Optional named parameters.
  # @return [Object] The return value of the Pry command.
  # @option options [Object, Binding] :context The object context to run the
  #   command under. Defaults to `TOPLEVEL_BINDING` (main).
  # @option options [Boolean] :show_output Whether to show command
  #   output. Defaults to true.
  # @example Run at top-level with no output.
  #   Pry.run_command "ls"
  # @example Run under Pry class, returning only public methods.
  #   Pry.run_command "ls -m", :context => Pry
  # @example Display command output.
  #   Pry.run_command "ls -av", :show_output => true
  def self.run_command(command_string, options={})
    options = {
      :context => TOPLEVEL_BINDING,
      :show_output => true,
      :output => Pry.output,
      :commands => Pry.commands
    }.merge!(options)

    output = options[:show_output] ? options[:output] : StringIO.new

    Pry.new(:output => output, :input => StringIO.new(command_string), :commands => options[:commands], :prompt => proc {""}, :hooks => Pry::Hooks.new).rep(options[:context])
  end

  def self.default_editor_for_platform
    return ENV['VISUAL'] if ENV['VISUAL'] and not ENV['VISUAL'].empty?
    return ENV['EDITOR'] if ENV['EDITOR'] and not ENV['EDITOR'].empty?

    if Helpers::BaseHelpers.windows?
      'notepad'
    else
      %w(editor nano vi).detect do |editor|
        system("which #{editor} > /dev/null 2>&1")
      end
    end
  end

  def self.set_config_defaults
    config.input = Readline
    config.output = $stdout
    config.commands = Pry::Commands
    config.prompt = DEFAULT_PROMPT
    config.print = DEFAULT_PRINT
    config.exception_handler = DEFAULT_EXCEPTION_HANDLER
    config.exception_whitelist = DEFAULT_EXCEPTION_WHITELIST
    config.default_window_size = 5
    config.hooks = DEFAULT_HOOKS
    config.input_stack = []
    config.color = Helpers::BaseHelpers.use_ansi_codes?
    config.pager = true
    config.system = DEFAULT_SYSTEM
    config.editor = default_editor_for_platform
    config.should_load_rc = true
    config.should_trap_interrupts = Helpers::BaseHelpers.jruby?
    config.disable_auto_reload = false
    config.command_prefix = ""
    config.auto_indent = true
    config.correct_indent = true
    config.collision_warning = false

    config.gist ||= OpenStruct.new
    config.gist.inspecter = proc(&:pretty_inspect)

    config.should_load_plugins = true

    config.requires ||= []
    config.should_load_requires = true

    config.history ||= OpenStruct.new
    config.history.should_save = true
    config.history.should_load = true
    config.history.file = File.expand_path("~/.pry_history") rescue nil

    if config.history.file.nil?
      config.should_load_rc = false
      config.history.should_save = false
      config.history.should_load = false
    end

    config.control_d_handler = DEFAULT_CONTROL_D_HANDLER

    config.memory_size = 100

    config.ls ||= OpenStruct.new({
      :heading_color            => :default,

      :public_method_color      => :default,
      :private_method_color     => :green,
      :protected_method_color   => :yellow,
      :method_missing_color     => :bright_red,

      :local_var_color          => :default,
      :pry_var_color            => :red,         # e.g. _, _pry_, _file_

      :instance_var_color       => :blue,        # e.g. @foo
      :class_var_color          => :bright_blue, # e.g. @@foo

      :global_var_color         => :default,     # e.g. $CODERAY_DEBUG, $eventmachine_library
      :builtin_global_color     => :cyan,        # e.g. $stdin, $-w, $PID
      :pseudo_global_color      => :cyan,        # e.g. $~, $1..$9, $LAST_MATCH_INFO

      :constant_color           => :default,       # e.g. VERSION, ARGF
      :class_constant_color     => :blue,        # e.g. Object, Kernel
      :exception_constant_color => :magenta,     # e.g. Exception, RuntimeError

      # What should separate items listed by ls? (TODO: we should allow a columnar layout)
      :separator                => "  ",

      # Any methods defined on these classes, or modules included into these classes, will not
      # be shown by ls unless the -v flag is used.
      # A user of Rails may wih to add ActiveRecord::Base to the list.
      # add the following to your .pryrc:
      # Pry.config.ls.ceiling << ActiveRecord::Base if defined? ActiveRecordBase
      :ceiling                  => [Object, Module, Class]
    })
  end

  # Set all the configurable options back to their default values
  def self.reset_defaults
    set_config_defaults

    @initial_session = true

    self.custom_completions = DEFAULT_CUSTOM_COMPLETIONS
    self.cli = false
    self.current_line = 1
    self.line_buffer = [""]
    self.eval_path = "(pry)"
    self.active_sessions = 0

    fix_coderay_colors
  end

  # To avoid mass-confusion, we change the default colour of "white" to
  # "blue" enabling global legibility
  def self.fix_coderay_colors
      to_fix = if (CodeRay::Encoders::Terminal::TOKEN_COLORS rescue nil)
                 # CodeRay 1.0.0
                 CodeRay::Encoders::Terminal::TOKEN_COLORS
               else
                 # CodeRay 0.9
                 begin
                   require 'coderay/encoders/term'
                   CodeRay::Encoders::Term::TOKEN_COLORS
                 rescue => e
                 end
               end

      to_fix[:comment] = "0;34" if to_fix
  end

  # Basic initialization.
  def self.init
    @plugin_manager ||= PluginManager.new
    self.config ||= Config.new
    self.history ||= History.new

    reset_defaults
    locate_plugins
  end

  # Return a `Binding` object for `target` or return `target` if it is
  # already a `Binding`.
  # In the case where `target` is top-level then return `TOPLEVEL_BINDING`
  # @param [Object] target The object to get a `Binding` object for.
  # @return [Binding] The `Binding` object.
  def self.binding_for(target)
    if target.is_a?(Binding)
      target
    else
      if TOPLEVEL_BINDING.eval('self') == target
        TOPLEVEL_BINDING
      else
        target.__binding__
      end
    end
  end
end

Pry.init
