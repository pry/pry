class Pry::Config
  require 'ostruct'
  require 'pry/config/default'
  require 'pry/config/convenience'

  def self.shortcuts
    Convenience::SHORTCUTS
  end

  def initialize(default = Pry.config)
    @default = default
    @lookup = {}
    configure_gist
    configure_ls
    configure_history
  end

  def [](key)
    @lookup[key]
  end

  def []=(key, value)
    @lookup[key] = value
  end

  def method_missing(name, *args, &block)
    key = name.to_s
    if key[-1] == "="
      short_key = key.to_s[0..-2]
      @lookup[short_key] = args[0]
    elsif @lookup.has_key?(key)
      @lookup[key]
    elsif @default.respond_to?(name)
      @default.public_send(name, *args, &block)
    else
      nil
    end
  end

  def merge!(other)
    @lookup.merge!(other.to_h)
  end

  def respond_to?(name, boolean=false)
    @lookup.has_key?(name.to_s) or @default.respond_to?(name) or super(name, boolean)
  end

  def refresh
    @lookup = {}
  end

  def to_h
    @lookup
  end

  def quiet?
    quiet
  end

private
  # TODO:
  # all of this configure_* stuff is a relic of old code.
  # we should try move this code to being command-local.
  def configure_ls
    @lookup["ls"] = OpenStruct.new({
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
    @lookup["gist"] = OpenStruct.new
    gist.inspecter = proc(&:pretty_inspect)
  end

  def configure_history
    @lookup["history"] = OpenStruct.new
    history.should_save = true
    history.should_load = true
    history.file = File.expand_path("~/.pry_history") rescue nil
    if history.file.nil?
      self.should_load_rc = false
      history.should_save = false
      history.should_load = false
    end
  end
end
