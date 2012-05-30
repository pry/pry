require 'pry/slop/option'
require 'pry/slop/commands'

class Pry
class Slop
  include Enumerable

  VERSION = '3.2.0'

  # The main Error class, all Exception classes inherit from this class.
  class Error < StandardError; end

  # Raised when an option argument is expected but none are given.
  class MissingArgumentError < Error; end

  # Raised when an option is expected/required but not present.
  class MissingOptionError < Error; end

  # Raised when an argument does not match its intended match constraint.
  class InvalidArgumentError < Error; end

  # Raised when an invalid option is found and the strict flag is enabled.
  class InvalidOptionError < Error; end

  # Raised when an invalid command is found and the strict flag is enabled.
  class InvalidCommandError < Error; end

  # Returns a default Hash of configuration options this Slop instance uses.
  DEFAULT_OPTIONS = {
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
      init_and_parse(items, false, config, &block)
    end

    # items  - The Array of items to extract options from (default: ARGV).
    # config - The Hash of configuration options to send to Slop.new().
    # block  - An optional block used to add options.
    #
    # Returns a new instance of Slop.
    def parse!(items = ARGV, config = {}, &block)
      init_and_parse(items, true, config, &block)
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

    private

    # Convenience method used by ::parse and ::parse!.
    #
    # items  - The Array of items to parse.
    # delete - When true, executes #parse! over #parse.
    # config - The Hash of configuration options to pass to Slop.new.
    # block  - The optional block to pass to Slop.new
    #
    # Returns a newly created instance of Slop.
    def init_and_parse(items, delete, config, &block)
      config, items = items, ARGV if items.is_a?(Hash) && config.empty?
      slop = Slop.new(config, &block)
      delete ? slop.parse!(items) : slop.parse(items)
      slop
    end
  end

  # The Hash of configuration options for this Slop instance.
  attr_reader :config

  # The Array of Slop::Option objects tied to this Slop instance.
  attr_reader :options

  # Create a new instance of Slop and optionally build options via a block.
  #
  # config - A Hash of configuration options.
  # block  - An optional block used to specify options.
  def initialize(config = {}, &block)
    @config = DEFAULT_OPTIONS.merge(config)
    @options = []
    @trash = []
    @triggered_options = []
    @unknown_options = []
    @callbacks = {}
    @separators = {}

    if block_given?
      block.arity == 1 ? yield(self) : instance_eval(&block)
    end

    if config[:help]
      on('-h', '--help', 'Display this help message.', :tail => true) do
        $stderr.puts help
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
  #
  # Returns nothing.
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

  # Parse a list of items, executing and gathering options along the way.
  #
  # items - The Array of items to extract options from (default: ARGV).
  # block - An optional block which when used will yield non options.
  #
  # Returns an Array of original items.
  def parse(items = ARGV, &block)
    parse_items(items, false, &block)
  end

  # Parse a list of items, executing and gathering options along the way.
  # unlike parse() this method will remove any options and option arguments
  # from the original Array.
  #
  # items - The Array of items to extract options from (default: ARGV).
  # block - An optional block which when used will yield non options.
  #
  # Returns an Array of original items with options removed.
  def parse!(items = ARGV, &block)
    parse_items(items, true, &block)
  end

  # Add an Option.
  #
  # objects - An Array with an optional Hash as the last element.
  #
  # Examples:
  #
  #   on '-u', '--username=', 'Your username'
  #   on :v, :verbose, 'Enable verbose mode'
  #
  # Returns the created instance of Slop::Option.
  def on(*objects, &block)
    option = build_option(objects, &block)
    options << option
    option
  end
  alias option on
  alias opt on

  # Fetch an options argument value.
  #
  # key - The Symbol or String option short or long flag.
  #
  # Returns the Object value for this option, or nil.
  def [](key)
    option = fetch_option(key)
    option.value if option
  end
  alias get []

  # Returns a new Hash with option flags as keys and option values as values.
  def to_hash
    Hash[options.map { |opt| [opt.key.to_sym, opt.value] }]
  end
  alias to_h to_hash

  # Enumerable interface. Yields each Slop::Option.
  def each(&block)
    options.each(&block)
  end

  # Check for an options presence.
  #
  # Examples:
  #
  #   opts.parse %w( --foo )
  #   opts.present?(:foo) #=> true
  #   opts.present?(:bar) #=> false
  #
  # Returns true if all of the keys are present in the parsed arguments.
  def present?(*keys)
    keys.all? { |key| (opt = fetch_option(key)) && opt.count > 0 }
  end

  # Convenience method for present?(:option).
  #
  # Examples:
  #
  #   opts.parse %( --verbose )
  #   opts.verbose? #=> true
  #   opts.other?   #=> false
  #
  # Returns true if this option is present. If this method does not end
  # with a ? character it will instead call super().
  def method_missing(method, *args, &block)
    meth = method.to_s
    if meth.end_with?('?')
      present?(meth.chop)
    else
      super
    end
  end

  # Override this method so we can check if an option? method exists.
  #
  # Returns true if this option key exists in our list of options.
  def respond_to?(method)
    method = method.to_s
    if method.end_with?('?') && options.any? { |o| o.key == method.chop }
      true
    else
      super
    end
  end

  # Fetch a list of options which were missing from the parsed list.
  #
  # Examples:
  #
  #   opts = Slop.new do
  #     on :n, :name=
  #     on :p, :password=
  #   end
  #
  #   opts.parse %w[ --name Lee ]
  #   opts.missing #=> ['password']
  #
  # Returns an Array of Strings representing missing options.
  def missing
    (options - @triggered_options).map(&:key)
  end

  # Fetch a Slop::Option object.
  #
  # key - The Symbol or String option key.
  #
  # Examples:
  #
  #   opts.on(:foo, 'Something fooey', :argument => :optional)
  #   opt = opts.fetch_option(:foo)
  #   opt.class #=> Slop::Option
  #   opt.accepts_optional_argument? #=> true
  #
  # Returns an Option or nil if none were found.
  def fetch_option(key)
    options.find { |option| [option.long, option.short].include?(clean(key)) }
  end

  # Add a callback.
  #
  # label - The Symbol identifier to attach this callback.
  #
  # Returns nothing.
  def add_callback(label, &block)
    (@callbacks[label] ||= []) << block
  end

  # Add string separators between options.
  #
  # text - The String text to print.
  def separator(text)
    if @separators[options.size]
      @separators[options.size] << "\n#{text}"
    else
      @separators[options.size] = text
    end
  end

  # Print a handy Slop help string.
  #
  # Returns the banner followed by available option help strings.
  def to_s
    heads  = options.reject(&:tail?)
    tails  = (options - heads)
    opts = (heads + tails).select(&:help).map(&:to_s)
    optstr = opts.each_with_index.map { |o, i|
      (str = @separators[i + 1]) ? [o, str].join("\n") : o
    }.join("\n")

    if config[:banner]
      config[:banner] << "\n"
      config[:banner] << "#{@separators[0]}\n" if @separators[0]
      config[:banner] + optstr
    else
      optstr
    end
  end
  alias help to_s

  # Returns the String inspection text.
  def inspect
    "#<Slop #{config.inspect} #{options.map(&:inspect)}>"
  end

  private

  # Parse a list of items and process their values.
  #
  # items  - The Array of items to process.
  # delete - True to remove any triggered options and arguments from the
  #          original list of items.
  # block  - An optional block which when passed will yields non-options.
  #
  # Returns the original Array of items.
  def parse_items(items, delete, &block)
    if items.empty? && @callbacks[:empty]
      @callbacks[:empty].each { |cb| cb.call(self) }
      return items
    end

    items.each_with_index do |item, index|
      @trash << index && break if item == '--'
      autocreate(items, index) if config[:autocreate]
      process_item(items, index, &block) unless @trash.include?(index)
    end
    items.reject!.with_index { |item, index| @trash.include?(index) } if delete

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

    items
  end

  # Process a list item, figure out if it's an option, execute any
  # callbacks, assign any option arguments, and do some sanity checks.
  #
  # items - The Array of items to process.
  # index - The current Integer index of the item we want to process.
  # block - An optional block which when passed will yield non options.
  #
  # Returns nothing.
  def process_item(items, index, &block)
    return unless item = items[index]
    option, argument = extract_option(item) if item.start_with?('-')

    if option
      option.count += 1 unless item.start_with?('--no-')
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

        if argument && argument =~ /\A([^-\-?]|-\d)+/
          execute_option(option, argument, index, item)
        else
          option.call(nil)
        end
      elsif config[:multiple_switches] && argument
        execute_multiple_switches(option, argument, index)
      else
        option.value = option.count > 0
        option.call(nil)
      end
    else
      @unknown_options << item if strict? && item =~ /\A--?/
      block.call(item) if block && !@trash.include?(index)
    end
  end

  # Execute an option, firing off callbacks and assigning arguments.
  #
  # option   - The Slop::Option object found by #process_item.
  # argument - The argument Object to assign to this option.
  # index    - The current Integer index of the object we're processing.
  # item     - The optional String item we're processing.
  #
  # Returns nothing.
  def execute_option(option, argument, index, item = nil)
    if !option
      if config[:multiple_switches] && strict?
        raise InvalidOptionError, "Unknown option -#{item}"
      end
      return
    end

    @trash << index + 1 unless item && item.end_with?("=#{argument}")
    option.value = argument

    if option.match? && !argument.match(option.config[:match])
      raise InvalidArgumentError, "#{argument} is an invalid argument"
    end

    option.call(option.value)
  end

  # Execute a `-abc` type option where a, b and c are all options. This
  # method is only executed if the multiple_switches argument is true.
  #
  # option   - The first Option object.
  # argument - The argument to this option. (Split into multiple Options).
  # index    - The index of the current item being processed.
  #
  # Returns nothing.
  def execute_multiple_switches(option, argument, index)
    execute_option(option, argument, index)
    argument.split('').each do |key|
      opt = fetch_option(key)
      opt.count += 1
      execute_option(opt, argument, index, key)
    end
  end

  # Extract an option from a flag.
  #
  # flag - The flag key used to extract an option.
  #
  # Returns an Array of [option, argument].
  def extract_option(flag)
    option = fetch_option(flag)
    option ||= fetch_option(flag.downcase) if config[:ignore_case]
    option ||= fetch_option(flag.gsub(/([^-])-/, '\1_'))

    unless option
      case flag
      when /\A--?([^=]+)=(.+)\z/, /\A-([a-zA-Z])(.+)\z/, /\A--no-(.+)\z/
        option, argument = fetch_option($1), ($2 || false)
      end
    end

    [option, argument]
  end

  # Autocreate an option on the fly. See the :autocreate Slop config option.
  #
  # items - The Array of items we're parsing.
  # index - The current Integer index for the item we're processing.
  #
  # Returns nothing.
  def autocreate(items, index)
    flag = items[index]
    unless present?(flag)
      option = build_option(Array(flag))
      argument = items[index + 1]
      option.config[:argument] = (argument && argument !~ /\A--?/)
      option.config[:autocreated] = true
      options << option
    end
  end

  # Build an option from a list of objects.
  #
  # objects - An Array of objects used to build this option.
  #
  # Returns a new instance of Slop::Option.
  def build_option(objects, &block)
    config = {}
    config[:argument] = true if @config[:arguments]
    config[:optional_argument] = true if @config[:optional_arguments]

    if objects.last.is_a?(Hash)
      config = config.merge!(objects.last)
      objects.pop
    end
    short = extract_short_flag(objects, config)
    long  = extract_long_flag(objects, config)
    desc  = objects[0].respond_to?(:to_str) ? objects.shift : nil

    Option.new(self, short, long, desc, config, &block)
  end

  # Extract the short flag from an item.
  #
  # objects - The Array of objects passed from #build_option.
  # config  - The Hash of configuration options built in #build_option.
  def extract_short_flag(objects, config)
    flag = clean(objects.first)

    if flag.size == 2 && flag.end_with?('=')
      config[:argument] ||= true
      flag.chop!
    end

    if flag.size == 1
      objects.shift
      flag
    end
  end

  # Extract the long flag from an item.
  #
  # objects - The Array of objects passed from #build_option.
  # config  - The Hash of configuration options built in #build_option.
  def extract_long_flag(objects, config)
    flag = objects.first.to_s
    if flag =~ /\A(?:--?)?[a-zA-Z][a-zA-Z0-9_-]+\=?\??\z/
      config[:argument] ||= true if flag.end_with?('=')
      config[:optional_argument] = true if flag.end_with?('=?')
      objects.shift
      clean(flag).sub(/\=\??\z/, '')
    end
  end

  # Remove any leading -- characters from a string.
  #
  # object - The Object we want to cast to a String and clean.
  #
  # Returns the newly cleaned String with leading -- characters removed.
  def clean(object)
    object.to_s.sub(/\A--?/, '')
  end

end
end
