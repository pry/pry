class Pry
class Slop
  class Commands
    include Enumerable

    attr_reader :config, :commands
    attr_writer :banner

    # Create a new instance of Slop::Commands and optionally build
    # Slop instances via a block. Any configuration options used in
    # this method will be the default configuration options sent to
    # each Slop object created.
    #
    # config - An optional configuration Hash.
    # block  - Optional block used to define commands.
    #
    # Examples:
    #
    #   commands = Slop::Commands.new do
    #     on :new do
    #       on '-o', '--outdir=', 'The output directory'
    #       on '-v', '--verbose', 'Enable verbose mode'
    #     end
    #
    #     on :generate do
    #       on '--assets', 'Generate assets', :default => true
    #     end
    #
    #     global do
    #       on '-D', '--debug', 'Enable debug mode', :default => false
    #     end
    #   end
    #
    #   commands[:new].class #=> Slop
    #   commands.parse
    #
    def initialize(config = {}, &block)
      @config = config
      @commands = {}
      @banner = nil

      if block_given?
        block.arity == 1 ? yield(self) : instance_eval(&block)
      end
    end

    # Optionally set the banner for this command help output.
    #
    # banner - The String text to set the banner.
    #
    # Returns the String banner if one is set.
    def banner(banner = nil)
      @banner = banner if banner
      @banner
    end

    # Add a Slop instance for a specific command.
    #
    # command - A String or Symbol key used to identify this command.
    # config  - A Hash of configuration options to pass to Slop.
    # block   - An optional block used to pass options to Slop.
    #
    # Returns the newly created Slop instance mapped to command.
    def on(command, config = {}, &block)
      commands[command.to_s] = Slop.new(@config.merge(config), &block)
    end

    # Add a Slop instance used when no other commands exist.
    #
    # config - A Hash of configuration options to pass to Slop.
    # block  - An optional block used to pass options to Slop.
    #
    # Returns the newly created Slop instance mapped to default.
    def default(config = {}, &block)
      on('default', config, &block)
    end

    # Add a global Slop instance.
    #
    # config - A Hash of configuration options to pass to Slop.
    # block  - An optional block used to pass options to Slop.
    #
    # Returns the newly created Slop instance mapped to global.
    def global(config = {}, &block)
      on('global', config, &block)
    end

    # Fetch the instance of Slop tied to a command.
    #
    # key - The String or Symbol key used to locate this command.
    #
    # Returns the Slop instance if this key is found, nil otherwise.
    def [](key)
      commands[key.to_s]
    end
    alias get []

    # Parse a list of items.
    #
    # items - The Array of items to parse.
    #
    # Returns the original Array of items.
    def parse(items = ARGV)
      parse_items(items)
    end

    # Enumerable interface.
    def each(&block)
      @commands.each(&block)
    end

    # Parse a list of items, removing any options or option arguments found.
    #
    # items - The Array of items to parse.
    #
    # Returns the original Array of items with options removed.
    def parse!(items = ARGV)
      parse_items(items, true)
    end

    # Returns a nested Hash with Slop options and values. See Slop#to_hash.
    def to_hash
      Hash[commands.map { |k, v| [k.to_sym, v.to_hash] }]
    end

    # Returns the help String.
    def to_s
      defaults = commands.delete('default')
      globals = commands.delete('global')
      helps = commands.reject { |_, v| v.options.none? }
      helps.merge!('Global options' => globals.to_s) if globals
      helps.merge!('Other options' => defaults.to_s) if defaults
      banner = @banner ? "#{@banner}\n" : ""
      banner + helps.map { |key, opts| "  #{key}\n#{opts}" }.join("\n\n")
    end
    alias help to_s

    # Returns the inspection String.
    def inspect
      "#<Slop::Commands #{config.inspect} #{commands.values.map(&:inspect)}>"
    end

    private

    # Parse a list of items.
    #
    # items - The Array of items to parse.
    # bang  - When true, #parse! will be called instead of #parse.
    #
    # Returns the Array of items (with options removed if bang == true).
    def parse_items(items, bang = false)
      if opts = commands[items[0].to_s]
        items.shift
        bang ? opts.parse!(items) : opts.parse(items)
        execute_global_opts(items, bang)
      else
        if opts = commands['default']
          bang ? opts.parse!(items) : opts.parse(items)
        else
          if config[:strict] && items[0]
            raise InvalidCommandError, "Unknown command `#{items[0]}`"
          end
        end
        execute_global_opts(items, bang)
      end
      items
    end

    def execute_global_opts(items, bang)
      if global_opts = commands['global']
        bang ? global_opts.parse!(items) : global_opts.parse(items)
      end
    end

  end
end
end
