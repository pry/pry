class Pry
  class NoCommandError < StandardError
    def initialize(name, owner)
      super "Command '#{name}' not found in command set #{owner}"
    end
  end

  # This class is used to create sets of commands. Commands can be imported from
  # different sets, aliased, removed, etc.
  class CommandSet
    include Enumerable
    include Pry::Helpers::BaseHelpers

    attr_reader :commands
    attr_reader :helper_module

    # @param [Array<CommandSet>] imported_sets Sets which will be imported
    #   automatically
    # @yield Optional block run to define commands
    def initialize(*imported_sets, &block)
      @commands      = {}
      @helper_module = Module.new

      import(*imported_sets)

      instance_eval(&block) if block
    end

    # Defines a new Pry command.
    # @param [String, Regexp] name The name of the command. Can be
    #   Regexp as well as String.
    # @param [String] description A description of the command.
    # @param [Hash] options The optional configuration parameters.
    # @option options [Boolean] :keep_retval Whether or not to use return value
    #   of the block for return of `command` or just to return `nil`
    #   (the default).
    # @option options [Array<String>] :requires_gem Whether the command has
    #   any gem dependencies, if it does and dependencies not met then
    #   command is disabled and a stub proc giving instructions to
    #   install command is provided.
    # @option options [Boolean] :interpolate Whether string #{} based
    #   interpolation is applied to the command arguments before
    #   executing the command. Defaults to true.
    # @option options [String] :listing The listing name of the
    #   command. That is the name by which the command is looked up by
    #   help and by show-command. Necessary for regex based commands.
    # @option options [Boolean] :use_prefix Whether the command uses
    #   `Pry.config.command_prefix` prefix (if one is defined). Defaults
    #   to true.
    # @option options [Boolean] :shellwords Whether the command's arguments
    #   should be split using Shellwords instead of just split on spaces.
    #   Defaults to true.
    # @yield The action to perform. The parameters in the block
    #   determines the parameters the command will receive. All
    #   parameters passed into the block will be strings. Successive
    #   command parameters are separated by whitespace at the Pry prompt.
    # @example
    #   MyCommands = Pry::CommandSet.new do
    #     command "greet", "Greet somebody" do |name|
    #       puts "Good afternoon #{name.capitalize}!"
    #     end
    #   end
    #
    #   # From pry:
    #   # pry(main)> _pry_.commands = MyCommands
    #   # pry(main)> greet john
    #   # Good afternoon John!
    #   # pry(main)> help greet
    #   # Greet somebody
    # @example Regexp command
    #   MyCommands = Pry::CommandSet.new do
    #     command /number-(\d+)/, "number-N regex command", :listing => "number" do |num, name|
    #       puts "hello #{name}, nice number: #{num}"
    #     end
    #   end
    #
    #   # From pry:
    #   # pry(main)> _pry_.commands = MyCommands
    #   # pry(main)> number-10 john
    #   # hello john, nice number: 10
    #   # pry(main)> help number
    #   # number-N regex command
    def block_command(name, description="No description.", options={}, &block)
      description, options = ["No description.", description] if description.is_a?(Hash)
      options = default_options(name).merge!(options)

      commands[name] = Pry::BlockCommand.subclass(name, description, options, helper_module, &block)
    end
    alias_method :command, :block_command

    # Defines a new Pry command class.
    #
    # @param [String, Regexp] name The name of the command. Can be
    #   Regexp as well as String.
    # @param [String] description A description of the command.
    # @param [Hash] options The optional configuration parameters, see {#command}
    # @param &Block  The class body's definition.
    #
    # @example
    #   Pry::Commands.create_command "echo", "echo's the input", :shellwords => false do
    #     def options(opt)
    #       opt.banner "Usage: echo [-u | -d] <string to echo>"
    #       opt.on :u, :upcase, "ensure the output is all upper-case"
    #       opt.on :d, :downcase, "ensure the output is all lower-case"
    #     end
    #
    #     def process
    #       raise Pry::CommandError, "-u and -d makes no sense" if opts.present?(:u) && opts.present?(:d)
    #       result = args.join(" ")
    #       result.downcase! if opts.present?(:downcase)
    #       result.upcase! if opts.present?(:upcase)
    #       output.puts result
    #     end
    #   end
    #
    def create_command(name, description="No description.", options={}, &block)
      description, options = ["No description.", description] if description.is_a?(Hash)
      options = default_options(name).merge!(options)

      commands[name] = Pry::ClassCommand.subclass(name, description, options, helper_module, &block)
      commands[name].class_eval(&block)
      commands[name]
    end

    # Execute a block of code before a command is invoked. The block also
    # gets access to parameters that will be passed to the command and
    # is evaluated in the same context.
    # @param [String, Regexp] name The name of the command.
    # @yield The block to be run before the command.
    # @example Display parameter before invoking command
    #   Pry.commands.before_command("whereami") do |n|
    #     output.puts "parameter passed was #{n}"
    #   end
    def before_command(name, &block)
      cmd = find_command_by_name_or_listing(name)
      cmd.hooks[:before].unshift block
    end

    # Execute a block of code after a command is invoked. The block also
    # gets access to parameters that will be passed to the command and
    # is evaluated in the same context.
    # @param [String, Regexp] name The name of the command.
    # @yield The block to be run after the command.
    # @example Display text 'command complete' after invoking command
    #   Pry.commands.after_command("whereami") do |n|
    #     output.puts "command complete!"
    #   end
    def after_command(name, &block)
      cmd = find_command_by_name_or_listing(name)
      cmd.hooks[:after] << block
    end

    def each &block
      @commands.each(&block)
    end

    # Removes some commands from the set
    # @param [Array<String>] names name of the commands to remove
    def delete(*names)
      names.each do |name|
        cmd = find_command_by_name_or_listing(name)
        commands.delete cmd.name
      end
    end

    # Imports all the commands from one or more sets.
    # @param [Array<CommandSet>] sets Command sets, all of the commands of which
    #   will be imported.
    def import(*sets)
      sets.each do |set|
        commands.merge! set.commands
        helper_module.send :include, set.helper_module
      end
    end

    # Imports some commands from a set
    # @param [CommandSet] set Set to import commands from
    # @param [Array<String>] names Commands to import
    def import_from(set, *names)
      helper_module.send :include, set.helper_module
      names.each do |name|
        cmd = set.find_command_by_name_or_listing(name)
        commands[cmd.name] = cmd
      end
    end

    # @param [String, Regexp] name_or_listing The name or listing name
    #   of the command to retrieve.
    # @return [Command] The command object matched.
    def find_command_by_name_or_listing(name_or_listing)
      if commands[name_or_listing]
        cmd = commands[name_or_listing]
      else
        _, cmd = commands.find { |name, command| command.options[:listing] == name_or_listing }
      end

      raise ArgumentError, "Cannot find a command with name: '#{name_or_listing}'!" if !cmd
      cmd
    end
    protected :find_command_by_name_or_listing

    # Aliases a command
    # @param [String] new_name New name of the command.
    # @param [String] old_name Old name of the command.
    # @param [String, nil] desc New description of the command.
    def alias_command(new_name, old_name, desc="")
      orig_command = find_command_by_name_or_listing(old_name)
      commands[new_name] = orig_command.dup
      commands[new_name].name = new_name
      commands[new_name].description = desc
    end

    # Rename a command. Accepts either actual name or listing name for
    # the `old_name`.
    # `new_name` must be the actual name of the new command.
    # @param [String, Regexp] new_name The new name for the command.
    # @param [String, Regexp] old_name The command's current name.
    # @param [Hash] options The optional configuration parameters,
    #   accepts the same as the `command` method, but also allows the
    #   command description to be passed this way too.
    # @example Renaming the `ls` command and changing its description.
    #   Pry.config.commands.rename "dir", "ls", :description => "DOS friendly ls"
    def rename_command(new_name, old_name, options={})
      cmd = find_command_by_name_or_listing(old_name)

      options = {
        :listing     => new_name,
        :description => cmd.description
      }.merge!(options)

      commands[new_name] = cmd.dup
      commands[new_name].name = new_name
      commands[new_name].description = options.delete(:description)
      commands[new_name].options.merge!(options)
      commands.delete(cmd.name)
    end

    # Sets or gets the description for a command (replacing the old
    # description). Returns current description if no description
    # parameter provided.
    # @param [String, Regexp] name The command name.
    # @param [String] description The command description.
    # @example Setting
    #   MyCommands = Pry::CommandSet.new do
    #     desc "help", "help description"
    #   end
    # @example Getting
    #   Pry.config.commands.desc "amend-line"
    def desc(name, description=nil)
      cmd = find_command_by_name_or_listing(name)
      return cmd.description if !description

      cmd.description = description
    end

    # Defines helpers methods for this command sets.
    # Those helpers are only defined in this command set.
    #
    # @yield A block defining helper methods
    # @example
    #   helpers do
    #     def hello
    #       puts "Hello!"
    #     end
    #
    #     include OtherModule
    #   end
    def helpers(&block)
      helper_module.class_eval(&block)
    end


    # @return [Array] The list of commands provided by the command set.
    def list_commands
      commands.keys
    end

    # Find a command that matches the given line
    #
    # @param [String]  the line that may be a command invocation
    # @return [Pry::Command, nil]
    def find_command(val)
      commands.values.select{ |c| c.matches?(val) }.sort_by{ |c| c.match_score(val) }.last
    end

    # Find the command that the user might be trying to refer to.
    #
    # @param [String]  the user's search.
    # @return [Pry::Command, nil]
    def find_command_for_help(search)
      find_command(search) || (begin
        find_command_by_name_or_listing(search)
      rescue ArgumentError
        nil
      end)
    end

    # Is the given line a command invocation?
    #
    # @param [String]
    # @return [Boolean]
    def valid_command?(val)
      !!find_command(val)
    end

    # Process the given line to see whether it needs executing as a command.
    #
    # @param String  the line to execute
    # @param Hash  the context to execute the commands with
    # @return CommandSet::Result
    #
    def process_line(val, context={})
      if command = find_command(val)
        context = context.merge(:command_set => self)
        retval = command.new(context).process_line(val)
        Result.new(true, retval)
      else
        Result.new(false)
      end
    end

    # @nodoc  used for testing
    def run_command(context, name, *args)
      command = commands[name] or raise NoCommandError.new(name, self)
      command.new(context).call_safely(*args)
    end

    private

    def default_options(name)
      {
        :requires_gem => [],
        :keep_retval => false,
        :argument_required => false,
        :interpolate => true,
        :shellwords => true,
        :listing => name,
        :use_prefix => true,
        :takes_block => false
      }
    end
  end

  # Wraps the return result of process_commands, indicates if the
  # result IS a command and what kind of command (e.g void)
  class Result
    attr_reader :retval

    def initialize(is_command, retval = nil)
      @is_command, @retval = is_command, retval
    end

    # Is the result a command?
    # @return [Boolean]
    def command?
      @is_command
    end

    # Is the result a command and if it is, is it a void command?
    # (one that does not return a value)
    # @return [Boolean]
    def void_command?
      retval == Command::VOID_VALUE
    end
  end
end
