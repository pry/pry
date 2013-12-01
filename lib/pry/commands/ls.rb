require 'pry/commands/ls/grep'
require 'pry/commands/ls/formatter'
require 'pry/commands/ls/globals'
require 'pry/commands/ls/constants'
require 'pry/commands/ls/methods'
require 'pry/commands/ls/self_methods'
require 'pry/commands/ls/instance_vars'
require 'pry/commands/ls/local_names'
require 'pry/commands/ls/local_vars'

class Pry
  class Command::Ls < Pry::ClassCommand
    match 'ls'
    group 'Context'
    description 'Show the list of vars and methods in the current scope.'
    command_options :shellwords => false, :interpolate => false

    banner <<-'BANNER'
      Usage: ls [-m|-M|-p|-pM] [-q|-v] [-c|-i] [Object]
             ls [-g] [-l]

      ls shows you which methods, constants and variables are accessible to Pry. By
      default it shows you the local variables defined in the current shell, and any
      public methods or instance variables defined on the current object.

      The colours used are configurable using Pry.config.ls.*_color, and the separator
      is Pry.config.ls.separator.

      Pry.config.ls.ceiling is used to hide methods defined higher up in the
      inheritance chain, this is by default set to [Object, Module, Class] so that
      methods defined on all Objects are omitted. The -v flag can be used to ignore
      this setting and show all methods, while the -q can be used to set the ceiling
      much lower and show only methods defined on the object or its direct class.

      Also check out `find-method` command (run `help find-method`).
    BANNER


    def options(opt)
      opt.on :m, :methods,   "Show public methods defined on the Object (default)"
      opt.on :M, "instance-methods", "Show methods defined in a Module or Class"
      opt.on :p, :ppp,       "Show public, protected (in yellow) and private (in green) methods"
      opt.on :q, :quiet,     "Show only methods defined on object.singleton_class and object.class"
      opt.on :v, :verbose,   "Show methods and constants on all super-classes (ignores Pry.config.ls.ceiling)"
      opt.on :g, :globals,   "Show global variables, including those builtin to Ruby (in cyan)"
      opt.on :l, :locals,    "Show hash of local vars, sorted by descending size"
      opt.on :c, :constants, "Show constants, highlighting classes (in blue), and exceptions (in purple).\n" <<
      " " * 32 <<            "Constants that are pending autoload? are also shown (in yellow)"
      opt.on :i, :ivars,     "Show instance variables (in blue) and class variables (in bright blue)"
      opt.on :G, :grep,      "Filter output by regular expression", :argument => true

      if jruby?
        opt.on :J, "all-java", "Show all the aliases for methods from java (default is to show only prettiest)"
      end
    end

    attr_reader :interrogatee

    def process
      @interrogatee = args.empty? ? target_self : target.eval(args.join(' '))

      # Exclude -q, -v and --grep because they,
      # don't specify what the user wants to see.
      no_user_opts = !(
        opts[:methods] || opts['instance-methods'] || opts[:ppp] ||
        opts[:globals] || opts[:locals] || opts[:constants] || opts[:ivars]
      )

      raise_errors_if_arguments_are_weird

      grep = Grep.new(Regexp.new(opts[:G] || '.'))
      greppable = proc { |o| o.grep = grep; o }

      entities = [
        greppable[Globals.new(target, opts)],
        greppable[Constants.new(interrogatee, target, no_user_opts, opts)],
        greppable[Methods.new(interrogatee, no_user_opts, opts)],
        greppable[SelfMethods.new(interrogatee, no_user_opts, opts)],
        InstanceVars.new(interrogatee, no_user_opts, opts),
        greppable[LocalNames.new(target, no_user_opts, _pry_.sticky_locals, args)],
        LocalVars.new(target, _pry_.sticky_locals, opts)
      ]

      stagger_output(entities.map(&:write_out).reject { |o| !o }.join(''))
    end

    private

    def raise_errors_if_arguments_are_weird
      [
        ['-l does not make sense with a specified Object', :locals,            !args.empty?],
        ['-g does not make sense with a specified Object', :globals,           !args.empty?],
        ['-q does not make sense with -v',                 :quiet,             opts.present?(:verbose)],
        ['-M only makes sense with a Module or a Class',   'instance-methods', !Module === interrogatee],
        ['-c only makes sense with a Module or a Class',   :constants,         !args.empty? && !Module === interrogatee],
      ].each do |message, option, expression|
        raise Pry::CommandError, message if opts.present?(option) && expression
      end
    end

  end

  Pry::Commands.add_command(Pry::Command::Ls)
end
