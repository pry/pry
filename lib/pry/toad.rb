# todo: fix.
class Pry::Toad
  class Error < StandardError; end
  class MissingArgumentError < Error; end
  class MissingOptionError < Error; end
  class InvalidArgumentError < Error; end
  class InvalidOptionError < Error; end
  class InvalidCommandError < Error; end

  DEFAULT_MAP = {
    :strict => false,
    :help => false,
    :banner => nil,
    :ignore_case => false,
    :autocreate => false,
    :arguments => false,
    :optional_arguments => false,
    :multiple_switches => true,
    :longest_flag => 0
  }

  class << self

    # items  - The Array of items to extract options from (default: ARGV).
    # config - The Hash of configuration options to send to Slop.new().
    # block  - An optional block used to add options.
    #
    # Examples:
    #
    #   Slop.parse(ARGV, :help => true) do
    #     on '-n', '--name', 'Your username', :argument => true
    #   end
    #
    # Returns a new instance of Slop.
    def parse(items = ARGV, config = {}, &block)
      parse! items.dup, config, &block
    end

    # items  - The Array of items to extract options from (default: ARGV).
    # config - The Hash of configuration options to send to Slop.new().
    # block  - An optional block used to add options.
    #
    # Returns a new instance of Slop.
    def parse!(items = ARGV, config = {}, &block)
      config, items = items, ARGV if items.is_a?(Hash) && config.empty?
      slop = new config, &block
      slop.parse! items
      slop
    end

    # Build a Slop object from a option specification.
    #
    # This allows you to design your options via a simple String rather
    # than programatically. Do note though that with this method, you're
    # unable to pass any advanced options to the on() method when creating
    # options.
    #
    # string - The optspec String
    # config - A Hash of configuration options to pass to Slop.new
    #
    # Examples:
    #
    #   opts = Slop.optspec(<<-SPEC)
    #   ruby foo.rb [options]
    #   ---
    #   n,name=     Your name
    #   a,age=      Your age
    #   A,auth      Sign in with auth
    #   p,passcode= Your secret pass code
    #   SPEC
    #
    #   opts.fetch_option(:name).description #=> "Your name"
    #
    # Returns a new instance of Slop.
    def optspec(string, config = {})
      warn "[DEPRECATED] `Slop.optspec` is deprecated and will be removed in version 4"
      config[:banner], optspec = string.split(/^--+$/, 2) if string[/^--+$/]
      lines = optspec.split("\n").reject(&:empty?)
      opts  = Slop.new(config)

      lines.each do |line|
        opt, description = line.split(' ', 2)
        short, long = opt.split(',').map { |s| s.sub(/\A--?/, '') }
        opt = opts.on(short, long, description)

        if long && long.end_with?('=')
          long.sub!(/\=$/, '')
          opt.config[:argument] = true
        end
      end

      opts
    end

  end

  # The Hash of configuration options for this Slop instance.
  attr_reader :store

  # The Array of Slop::Option objects tied to this Slop instance.
  attr_reader :options

  # The Hash of sub-commands for this Slop instance.
  attr_reader :commands

  # Create a new instance of Slop and optionally build options via a block.
  #
  # config - A Hash of configuration options.
  # block  - An optional block used to specify options.
  def initialize(config = {}, &block)
    @store = DEFAULT_OPTIONS.merge(config)
    @options = []
    @commands = {}
    @trash = []
    @triggered_options = []
    @unknown_options = []
    @callbacks = {}
    @separators = {}
    @runner = nil
    @command = config.delete(:command)

    if block_given?
      block.arity == 1 ? yield(self) : instance_eval(&block)
    end

    if config[:help]
      on('-h', '--help', 'Display this help message.', :tail => true) do
        puts help
        exit
      end
    end
  end

  # Is strict mode enabled?
  #
  # Returns true if strict mode is enabled, false otherwise.
  def strict?
    config[:strict]
  end

  # Set the banner.
  #
  # banner - The String to set the banner.
  def banner=(banner)
    config[:banner] = banner
  end

  # Get or set the banner.
  #
  # banner - The String to set the banner.
  #
  # Returns the banner String.
  def banner(banner = nil)
    config[:banner] = banner if banner
    config[:banner]
  end

  # Set the description (used for commands).
  #
  # desc - The String to set the description.
  def description=(desc)
    config[:description] = desc
  end

  # Get or set the description (used for commands).
  #
  # desc - The String to set the description.
  #
  # Returns the description String.
  def description(desc = nil)
    config[:description] = desc if desc
    config[:description]
  end

  # Add a new command.
  #
  # command - The Symbol or String used to identify this command.
  # options - A Hash of configuration options (see Slop::new)
  #
  # Returns a new instance of Slop mapped to this command.
  def command(command, options = {}, &block)
    options = @store.merge(options)
    @commands[command.to_s] = Slop.new(options.merge(:command => command.to_s), &block)
  end

  def parse(items = ARGV, &block)
    parse! items.dup, &block
    items
  end

  def parse!(items = ARGV, &block)
    if items.empty? && @callbacks[:empty]
      @callbacks[:empty].each { |cb| cb.call(self) }
      return items
    end


    if cmd = @commands[items[0]]
      items.shift
      return cmd.parse! items
    end

    items.each_with_index do |item, index|
      @trash << index && break if item == '--'
      autocreate(items, index) if config[:autocreate]
      process_item(items, index, &block) unless @trash.include?(index)
    end
    items.reject!.with_index { |item, index| @trash.include?(index) }

    missing_options = options.select { |opt| opt.required? && opt.count < 1 }
    if missing_options.any?
      raise MissingOptionError,
      "Missing required option(s): #{missing_options.map(&:key).join(', ')}"
    end

    if @unknown_options.any?
      raise InvalidOptionError, "Unknown options #{@unknown_options.join(', ')}"
    end

    if @triggered_options.empty? && @callbacks[:no_options]
      @callbacks[:no_options].each { |cb| cb.call(self) }
    end

    if @runner.respond_to?(:call)
      @runner.call(self, items) unless config[:help] and present?(:help)
    end

    items
  end

  def on(*objects, &block)
    option = build_option(objects, &block)
    original = options.find do |o|
      o.long and o.long == option.long or o.short and o.short == option.short
    end
    options.delete(original) if original
    options << option
    option
  end
  alias option on
  alias opt on


  def [](key)
    option = fetch_option(key)
    option.value if option
  end
  alias get []

  def to_hash(include_commands = false)
    hash = Hash[options.map { |opt| [opt.key.to_sym, opt.value] }]
    if include_commands
      @commands.each { |cmd, opts| hash.merge!(cmd.to_sym => opts.to_hash) }
    end
    hash
  end

  def each(&block)
    options.each(&block)
  end

  def run(callable = nil, &block)
    @runner = callable || block
    unless @runner.respond_to?(:call)
      raise ArgumentError, "You must specify a callable object or a block to #run"
    end
  end

  def present?(*keys)
    keys.all? { |key| (opt = fetch_option(key)) && opt.count > 0 }
  end

  def respond_to_missing?(method_name, include_private = false)
    options.any? { |o| o.key == method_name.to_s.chop } || super
  end

  def missing
    (options - @triggered_options).map(&:key)
  end

  def fetch_option(key)
    options.find { |option| [option.long, option.short].include?(clean(key)) }
  end

  def fetch_command(command)
    @commands[command.to_s]
  end

  def add_callback(label, &block)
    (@callbacks[label] ||= []) << block
  end

  def separator(text)
    if @separators[options.size]
      @separators[options.size] << "\n#{text}"
    else
      @separators[options.size] = text
    end
  end

  def to_s
    heads  = options.reject(&:tail?)
    tails  = (options - heads)
    opts = (heads + tails).select(&:help).map(&:to_s)
    optstr = opts.each_with_index.map { |o, i|
      (str = @separators[i + 1]) ? [o, str].join("\n") : o
    }.join("\n")

    if @commands.any?
      optstr << "\n" if !optstr.empty?
      optstr << "\nAvailable commands:\n\n"
      optstr << commands_to_help
      optstr << "\n\nSee `<command> --help` for more information on a specific command."
    end

    banner = config[:banner]
    if banner.nil?
      banner = "Usage: #{File.basename($0, '.*')}"
      banner << " #{@command}" if @command
      banner << " [command]" if @commands.any?
      banner << " [options]"
    end
    if banner
      "#{banner}\n#{@separators[0] ? "#{@separators[0]}\n" : ''}#{optstr}"
    else
      optstr
    end
  end
  alias help to_s

  private

  def method_missing(method, *args, &block)
    meth = method.to_s
    if meth.end_with?('?')
      meth.chop!
      present?(meth) || present?(meth.gsub('_', '-'))
    else
      super
    end
  end

  def process_item(items, index, &block)
    return unless item = items[index]
    option, argument = extract_option(item) if item.start_with?('-')

    if option
      option.count += 1 unless item.start_with?('--no-')
      option.count += 1 if option.key[0, 3] == "no-"
      @trash << index
      @triggered_options << option

      if option.expects_argument?
        argument ||= items.at(index + 1)

        if !argument || argument =~ /\A--?[a-zA-Z][a-zA-Z0-9_-]*\z/
          raise MissingArgumentError, "#{option.key} expects an argument"
        end

        execute_option(option, argument, index, item)
      elsif option.accepts_optional_argument?
        argument ||= items.at(index + 1)

        if argument && argument =~ /\A([^\-?]|-\d)+/
          execute_option(option, argument, index, item)
        else
          option.call(nil)
        end
      elsif config[:multiple_switches] && argument
        execute_multiple_switches(option, argument, items, index)
      else
        option.value = option.count > 0
        option.call(nil)
      end
    else
      @unknown_options << item if strict? && item =~ /\A--?/
      block.call(item) if block && !@trash.include?(index)
    end
  end

  def execute_option(option, argument, index, item = nil)
    if !option
      if config[:multiple_switches] && strict?
        raise InvalidOptionError, "Unknown option -#{item}"
      end
      return
    end

    if argument
      unless item && item.end_with?("=#{argument}")
        @trash << index + 1 unless option.argument_in_value
      end
      option.value = argument
    else
      option.value = option.count > 0
    end

    if option.match? && !argument.match(option.config[:match])
      raise InvalidArgumentError, "#{argument} is an invalid argument"
    end

    option.call(option.value)
  end

  def execute_multiple_switches(option, argument, items, index)
    execute_option(option, nil, index)
    flags = argument.split('')
    flags.each do |key|
      if opt = fetch_option(key)
        opt.count += 1
        if (opt.expects_argument? || opt.accepts_optional_argument?) &&
            (flags[-1] == opt.key) && (val = items[index+1])
          execute_option(opt, val, index, key)
        else
          execute_option(opt, nil, index, key)
        end
      else
        raise InvalidOptionError, "Unknown option -#{key}" if strict?
      end
    end
  end

  def extract_option(flag)
    option = fetch_option(flag)
    option ||= fetch_option(flag.downcase) if config[:ignore_case]
    option ||= fetch_option(flag.gsub(/([^-])-/, '\1_'))

    unless option
      case flag
      when /\A--?([^=]+)=(.+)\z/, /\A-([a-zA-Z])(.+)\z/, /\A--no-(.+)\z/
        option, argument = fetch_option($1), ($2 || false)
        option.argument_in_value = true if option
      end
    end

    [option, argument]
  end

  def autocreate(items, index)
    flag = items[index]
    if !fetch_option(flag) && !@trash.include?(index)
      option = build_option(Array(flag))
      argument = items[index + 1]
      option.config[:argument] = (argument && argument !~ /\A--?/)
      option.config[:autocreated] = true
      options << option
    end
  end

  def build_option(objects, &block)
    config = {}
    config[:argument] = true if @store[:arguments]
    config[:optional_argument] = true if @store[:optional_arguments]

    if objects.last.is_a?(Hash)
      config.merge!(objects.pop)
    end

    short = extract_short_flag(objects, config)
    long  = extract_long_flag(objects, config)
    desc  = objects.shift if objects[0].respond_to?(:to_str)

    Option.new(self, short, long, desc, config, &block)
  end

  def extract_short_flag(objects, config)
    flag = objects[0].to_s
    if flag =~ /\A-?\w=?\z/
      config[:argument] ||= flag.end_with?('=')
      objects.shift
      flag.delete('-=')
    end
  end

  def extract_long_flag(objects, config)
    flag = objects.first.to_s
    if flag =~ /\A(?:--?)?[a-zA-Z0-9][a-zA-Z0-9_.-]+\=?\??\z/
      config[:argument] ||= true if flag.end_with?('=')
      config[:optional_argument] = true if flag.end_with?('=?')
      objects.shift
      clean(flag).sub(/\=\??\z/, '')
    end
  end

  def clean(object)
    object.to_s.sub(/\A--?/, '')
  end

  def commands_to_help
    padding = 0
    @commands.each { |c, _| padding = c.size if c.size > padding }
    @commands.map do |cmd, opts|
      "  #{cmd}#{' ' * (padding - cmd.size)}   #{opts.description}"
    end.join("\n")
  end
end
