
class Pry

  # Manage the processing of command line options
  class CLI

    NoOptionsError = Class.new(StandardError)

    class << self

      # @return [Proc] The Proc defining the valid command line options.
      attr_accessor :options

      # @return [Array] The Procs that process the parsed options.
      attr_accessor :option_processors

      # Add another set of CLI options (a Slop block)
      def add_options(&block)
        if options
          old_options = options
          self.options = proc do
            instance_exec(&old_options)
            instance_exec(&block)
          end
        else
          self.options = block
        end

        self
      end

      # Bring in options defined in plugins
      def add_plugin_options
        Pry.plugins.values.each do |plugin|
          plugin.load_cli_options
        end

        self
      end

      # Add a block responsible for processing parsed options.
      def process_options(&block)
        self.option_processors ||= []
        option_processors << block

        self
      end

      # Clear `options` and `option_processors`
      def reset
        self.options           = nil
        self.option_processors = nil
      end

      def parse_options(args=ARGV.dup)
        raise NoOptionsError, "No command line options defined! Use Pry::CLI.add_options to add command line options." if !options

        opts = Slop.parse(args, :help => true, :multiple_switches => false, &options)
        option_processors.each { |processor| processor.call(opts) } if option_processors # option processors are optional

        self
      end

    end

    reset
  end
end

# Bring in options defined by plugins
Pry::CLI.add_plugin_options

# The default Pry command line options (before plugin options are included)
Pry::CLI.add_options do
  banner %{Usage: pry [OPTIONS]
Start a Pry session.
See: `https://github.com/pry` for more information.
Copyright (c) 2011 John Mair (banisterfiend)
--
}
  on :e, :exec, "A line of code to execute in context before the session starts", true

  on "no-pager", "Disable pager for long output" do
    Pry.config.pager = false
  end

  on "no-history", "Disable history loading" do
    Pry.config.history.should_load = false
  end

  on "no-color", "Disable syntax highlighting for session" do
    Pry.color = false
  end

  on :f, "Suppress loading of ~/.pryrc" do
    # load ~/.pryrc, if not suppressed with -f option
    Pry.config.should_load_rc = false
  end

  on "no-plugins", "Suppress loading of plugins." do
    # suppress plugins if given --no-plugins optino
    Pry.config.should_load_plugins = false
  end

  on "installed-plugins", "List installed plugins." do
    puts "Installed Plugins:"
    puts "--"
    Pry.locate_plugins.each do |plugin|
      puts "#{plugin.name}".ljust(18) + plugin.spec.summary
    end
    exit
  end

  on "simple-prompt", "Enable simple prompt mode" do
    Pry.config.prompt = Pry::SIMPLE_PROMPT
  end

  on :r, :require, "`require` a Ruby script at startup", true do |file|
    Pry.config.requires << file
  end

  on :I, "Add a path to the $LOAD_PATH", true do |path|
    $LOAD_PATH << path
  end

  on :v, :version, "Display the Pry version" do
    puts "Pry version #{Pry::VERSION} on Ruby #{RUBY_VERSION}"
    exit
  end

  on(:c, :context,
     "Start the session in the specified context. Equivalent to `context.pry` in a session.",
     true,
     :default => "TOPLEVEL_BINDING"
     )
end.process_options do |opts|
  # invoked via cli
  Pry.cli = true

  # create the actual context
  context = Pry.binding_for(eval(opts[:context]))

  if opts[:exec]
    exec_string = opts[:exec] + "\n"
  else
    exec_string = ""
  end

  # Start the session (running any code passed with -e, if there is any)
  Pry.start(context, :input => StringIO.new(exec_string))
end

