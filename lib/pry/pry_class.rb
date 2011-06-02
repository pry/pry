require 'ostruct'
require 'forwardable'
require 'pry/config'

# @author John Mair (banisterfiend)
class Pry

  # The RC Files to load.
  RC_FILES = ["~/.pryrc"]

  # class accessors
  class << self
    extend Forwardable

    # convenience method
    def self.delegate_accessors(delagatee, *names)
      def_delegators delagatee, *names
      def_delegators delagatee, *names.map { |v| "#{v}=" }
    end

    # Get nesting data.
    # This method should not need to be accessed directly.
    # @return [Array] The unparsed nesting information.
    attr_reader :nesting

    # Get last value evaluated by Pry.
    # This method should not need to be accessed directly.
    # @return [Object] The last result.
    attr_accessor :last_result

    # Get last exception raised.
    # This method should not need to be accessed directly.
    # @return [Exception] The last exception.
    attr_accessor :last_exception

    # Get the active Pry instance that manages the active Pry session.
    # This method should not need to be accessed directly.
    # @return [Pry] The active Pry instance.
    attr_accessor :active_instance

    # Get/Set the Proc that defines extra Readline completions (on top
    # of the ones defined for IRB).
    # @return [Proc] The Proc that defines extra Readline completions (on top
    # @example Add file names to completion list
    #   Pry.custom_completions = proc { Dir.entries('.') }
    attr_accessor :custom_completions

    # Value returned by last executed Pry command.
    # @return [Object] The command value
    attr_accessor :cmd_ret_value

    # @return [Fixnum] The current input line.
    attr_accessor :current_line

    # @return [Array] The Array of evaluated expressions.
    attr_accessor :line_buffer

    # @return [String] The __FILE__ for the `eval()`. Should be "(pry)"
    #   by default.
    attr_accessor :eval_path

    # @return [OpenStruct] Return Pry's config object.
    attr_accessor :config

    # @return [Boolean] Whether Pry was activated from the command line.
    attr_accessor :cli

    # plugin forwardables
    def_delegators :@plugin_manager, :plugins, :load_plugins, :locate_plugins

    delegate_accessors :@config, :input, :output, :commands, :prompt, :print, :exception_handler,
      :hooks, :color, :pager, :editor
  end

  # Load the rc files given in the `Pry::RC_FILES` array.
  # Defaults to loading just `~/.pryrc`. This method can also
  # be used to reload the files if they have changed.
  def self.load_rc
    RC_FILES.each do |file_name|
      file_name = File.expand_path(file_name)
      load(file_name) if File.exists?(file_name)
    end
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
    if initial_session?
      # note these have to be loaded here rather than in pry_instance as
      # we only want them loaded once per entire Pry lifetime, not
      # multiple times per each new session (i.e in debugging)
      load_rc if Pry.config.should_load_rc
      load_plugins if Pry.config.plugins.enabled
      load_history if Pry.config.history.load

      @initial_session = false
    end

    new(options).repl(target)
  end

  # A custom version of `Kernel#inspect`.
  # This method should not need to be accessed directly.
  # @param obj The object to view.
  # @return [String] The string representation of `obj`.
  def self.view(obj)
    obj.inspect

  rescue NoMethodError
    "unknown"
  end

  # A version of `Pry.view` that clips the output to `max_size` chars.
  # In case of > `max_size` chars the `#<Object...> notation is used.
  # @param obj The object to view.
  # @param max_size The maximum number of chars before clipping occurs.
  # @return [String] The string representation of `obj`.
  def self.view_clip(obj, max_size=60)
    if Pry.view(obj).size < max_size
      Pry.view(obj)
    else
      "#<#{obj.class}:%#x>" % (obj.object_id << 1)
    end
  end

  # Load Readline history if required.
  def self.load_history
    history_file = File.expand_path(Pry.config.history.file)
    Readline::HISTORY.push(*File.readlines(history_file).map(&:chomp)) if File.exists?(history_file)
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

    Pry.new(:output => output, :input => StringIO.new(command_string), :commands => options[:commands]).rep(options[:context])
  end

  def self.default_editor_for_platform
    if RUBY_PLATFORM =~ /mswin|mingw/
      ENV['EDITOR'] ? ENV['EDITOR'] : "notepad"
    else
      ENV['EDITOR'] ? ENV['EDITOR'] : "nano"
    end
  end

  def self.set_config_defaults
    config.input = Readline
    config.output = $stdout
    config.commands = Pry::Commands
    config.prompt = DEFAULT_PROMPT
    config.print = DEFAULT_PRINT
    config.exception_handler = DEFAULT_EXCEPTION_HANDLER
    config.hooks = DEFAULT_HOOKS
    config.color = true
    config.pager = true
    config.editor = default_editor_for_platform
    config.should_load_rc = true

    config.plugins ||= OpenStruct.new
    config.plugins.enabled = true
    config.plugins.strict_loading = true

    config.history ||= OpenStruct.new
    config.history.save = true
    config.history.load = true
    config.history.file = File.expand_path("~/.pry_history")
  end

  # Set all the configurable options back to their default values
  def self.reset_defaults
    set_config_defaults

    @initial_session = true

    self.custom_completions = DEFAULT_CUSTOM_COMPLETIONS
    self.cli = false
    self.current_line = 0
    self.line_buffer = []
    self.eval_path = "(pry)"
  end

  # Basic initialization.
  def self.init
    @plugin_manager ||= PluginManager.new

    self.config ||= Config.new
    reset_defaults
    locate_plugins
  end

  @nesting = []
  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end

  # Return all active Pry sessions.
  # @return [Array<Pry>] Active Pry sessions.
  def self.sessions
    # last element in nesting array is the pry instance
    nesting.map(&:last)
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
      if target == TOPLEVEL_BINDING.eval('self')
        TOPLEVEL_BINDING
      else
        target.__binding__
      end
    end
  end
end

Pry.init
