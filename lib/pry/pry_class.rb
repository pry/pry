require 'ostruct'
require 'pry/config'

class Pry

  # The RC Files to load.
  HOME_RC_FILE = ENV["PRYRC"] || "~/.pryrc"
  LOCAL_RC_FILE = "./.pryrc"

  # @return [Hash] Pry's `Thread.current` hash
  def self.current
    Thread.current[:__pry__] ||= {}
  end

  # Load the given file in the context of `Pry.toplevel_binding`
  # @param [String] file_name The unexpanded file path.
  def self.load_file_at_toplevel(file)
    toplevel_binding.eval(File.read(file), file)
  rescue RescuableException => e
    puts "Error loading #{file}: #{e}\n#{e.backtrace.first}"
  end

  # Load HOME_RC_FILE and LOCAL_RC_FILE if appropriate
  # This method can also be used to reload the files if they have changed.
  def self.load_rc_files
    rc_files_to_load.each do |file|
      load_file_at_toplevel(file)
    end
  end

  # Load the local RC file (./.pryrc)
  def self.rc_files_to_load
    files = []
    files << HOME_RC_FILE if Pry.config.should_load_rc
    files << LOCAL_RC_FILE if Pry.config.should_load_local_rc
    files.map { |file| real_path_to(file) }.compact.uniq
  end

  # Expand a file to its canonical name (following symlinks as appropriate)
  def self.real_path_to(file)
    expanded = Pathname.new(File.expand_path(file)).realpath.to_s
    # For rbx 1.9 mode [see rubinius issue #2165]
    File.exist?(expanded) ? expanded : nil
  rescue Errno::ENOENT
    nil
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

    return unless initial_session?
    @initial_session = false

    # note these have to be loaded here rather than in pry_instance as
    # we only want them loaded once per entire Pry lifetime.
    load_rc_files
    load_plugins if Pry.config.should_load_plugins
    load_requires if Pry.config.should_load_requires
    load_history if Pry.config.history.should_load
    load_traps if Pry.config.should_trap_interrupts
  end

  # Start a Pry REPL.
  # This method also loads `~/.pryrc` and `./.pryrc` as necessary the
  # first time it is invoked.
  # @param [Object, Binding] target The receiver of the Pry session
  # @param [Hash] options
  # @option options (see Pry#initialize)
  # @example
  #   Pry.start(Object.new, :input => MyInput.new)
  def self.start(target=nil, options={})
    return if ENV['DISABLE_PRY']

    if in_critical_section?
      output.puts "ERROR: Pry started inside Pry."
      output.puts "This can happen if you have a binding.pry inside a #to_s or #inspect function."
      return
    end

    options[:target] = Pry.binding_for(target || toplevel_binding)

    initial_session_setup

    # Unless we were given a backtrace, save the current one
    if options[:backtrace].nil?
      options[:backtrace] = caller

      # If Pry was started via `binding.pry`, elide that from the backtrace
      if options[:backtrace].first =~ /pry.*core_extensions.*pry/
        options[:backtrace].shift
      end
    end

    driver = options[:driver] || Pry::REPL

    # Enter the matrix
    driver.start(options)
  rescue Pry::TooSafeException
    puts "ERROR: Pry cannot work with $SAFE > 0"
    raise
  end

  # Execute the file through the REPL loop, non-interactively.
  # @param [String] file_name File name to load through the REPL.
  def self.load_file_through_repl(file_name)
    require "pry/repl_file_loader"
    REPLFileLoader.new(file_name).load
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
    elsif Pry.config.prompt_safe_objects.any? { |v| v === obj } && obj.inspect.length <= max_length
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

  # @return [Boolean] Whether this is the first time a Pry session has
  #   been started since loading the Pry class.
  def self.initial_session?
    @initial_session
  end

  # Run a Pry command from outside a session. The commands available are
  # those referenced by `Pry.commands` (the default command set).
  # @param [String] command_string The Pry command (including arguments,
  #   if any).
  # @param [Hash] options Optional named parameters.
  # @return [Object] The return value of the Pry command.
  # @option options [Object, Binding] :target The object to run the
  #   command under. Defaults to `TOPLEVEL_BINDING` (main).
  # @option options [Boolean] :show_output Whether to show command
  #   output. Defaults to true.
  # @example Run at top-level with no output.
  #   Pry.run_command "ls"
  # @example Run under Pry class, returning only public methods.
  #   Pry.run_command "ls -m", :target => Pry
  # @example Display command output.
  #   Pry.run_command "ls -av", :show_output => true
  def self.run_command(command_string, options={})
    options = {
      :target => TOPLEVEL_BINDING,
      :show_output => true,
      :output => Pry.output,
      :commands => Pry.commands
    }.merge!(options)

    # :context for compatibility with <= 0.9.11.4
    target = options[:context] || options[:target]
    output = options[:show_output] ? options[:output] : StringIO.new

    pry = Pry.new(:output   => output, :target   => target, :commands => options[:commands])
    pry.eval command_string
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

  def self.auto_resize!
    ver = Readline::VERSION
    if ver[/edit/i]
      warn <<-EOT
Readline version #{ver} detected - will not auto_resize! correctly.
  For the fix, use GNU Readline instead:
  https://github.com/guard/guard/wiki/Add-proper-Readline-support-to-Ruby-on-Mac-OS-X
      EOT
      return
    end
    trap :WINCH do
      begin
        Readline.set_screen_size(*Terminal.size!)
      rescue => e
        warn "\nPry.auto_resize!'s Readline.set_screen_size failed: #{e}"
      end
      begin
        Readline.refresh_line
      rescue => e
        warn "\nPry.auto_resize!'s Readline.refresh_line failed: #{e}"
      end
    end
  end

  def self.set_config_defaults
    config.input = Readline
    config.output = $stdout
    config.commands = Pry::Commands
    config.prompt_name = DEFAULT_PROMPT_NAME
    config.prompt = DEFAULT_PROMPT
    config.prompt_safe_objects = DEFAULT_PROMPT_SAFE_OBJECTS
    config.print = DEFAULT_PRINT
    config.exception_handler = DEFAULT_EXCEPTION_HANDLER
    config.exception_whitelist = DEFAULT_EXCEPTION_WHITELIST
    config.default_window_size = 5
    config.hooks = DEFAULT_HOOKS
    config.color = Helpers::BaseHelpers.use_ansi_codes?
    config.pager = true
    config.system = DEFAULT_SYSTEM
    config.editor = default_editor_for_platform
    config.should_load_rc = true
    config.should_load_local_rc = true
    config.should_trap_interrupts = Helpers::BaseHelpers.jruby?
    config.disable_auto_reload = false
    config.command_prefix = ""
    config.auto_indent = Helpers::BaseHelpers.use_ansi_codes?
    config.correct_indent = true
    config.collision_warning = false
    config.output_prefix = "=> "

    if defined?(Bond) && Readline::VERSION !~ /editline/i
      config.completer = Pry::BondCompleter.start
    else
      config.completer = Pry::InputCompleter.start
    end

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

    config.extra_sticky_locals = {}

    config.ls ||= OpenStruct.new({
      :heading_color            => :bright_blue,

      :public_method_color      => :default,
      :private_method_color     => :green,
      :protected_method_color   => :yellow,
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

      # What should separate items listed by ls?
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
    if Binding === target
      target
    else
      if TOPLEVEL_BINDING.eval('self') == target
        TOPLEVEL_BINDING
      else
        target.__binding__
      end
    end
  end

  def self.toplevel_binding
    unless defined?(@toplevel_binding) && @toplevel_binding
      # Grab a copy of the TOPLEVEL_BINDING without any local variables.
      # This binding has a default definee of Object, and new methods are
      # private (just as in TOPLEVEL_BINDING).
      TOPLEVEL_BINDING.eval <<-RUBY
        def self.__pry__
          binding
        end
        Pry.toplevel_binding = __pry__
        class << self; undef __pry__; end
      RUBY
    end
    @toplevel_binding.eval('private')
    @toplevel_binding
  end

  def self.toplevel_binding=(binding)
    @toplevel_binding = binding
  end

  def self.in_critical_section?
    Thread.current[:pry_critical_section] ||= 0
    Thread.current[:pry_critical_section] > 0
  end

  def self.critical_section(&block)
    Thread.current[:pry_critical_section] ||= 0
    Thread.current[:pry_critical_section] += 1
    yield
  ensure
    Thread.current[:pry_critical_section] -= 1
  end
end

Pry.init
