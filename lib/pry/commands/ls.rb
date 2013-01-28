class Pry
  class Command::Ls < Pry::ClassCommand
    match 'ls'
    group 'Context'
    description 'Show the list of vars and methods in the current scope.'
    command_options :shellwords => false, :interpolate => false

    def options(opt)
      opt.banner unindent <<-'BANNER'
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
      BANNER

      opt.on :m, :methods,   "Show public methods defined on the Object (default)"
      opt.on :M, "instance-methods", "Show methods defined in a Module or Class"
      opt.on :p, :ppp,       "Show public, protected (in yellow) and private (in green) methods"
      opt.on :q, :quiet,     "Show only methods defined on object.singleton_class and object.class"
      opt.on :v, :verbose,   "Show methods and constants on all super-classes (ignores Pry.config.ls.ceiling)"
      opt.on :g, :globals,   "Show global variables, including those builtin to Ruby (in cyan)"
      opt.on :l, :locals,    "Show hash of local vars, sorted by descending size"
      opt.on :c, :constants, "Show constants, highlighting classes (in blue), and exceptions (in purple).\n" +
      " " * 32 +             "Constants that are pending autoload? are also shown (in yellow)"
      opt.on :i, :ivars,     "Show instance variables (in blue) and class variables (in bright blue)"
      opt.on :G, :grep,      "Filter output by regular expression", :argument => true

      if jruby?
        opt.on :J, "all-java", "Show all the aliases for methods from java (default is to show only prettiest)"
      end
    end

    attr_reader :object_to_interrogate, :has_user_specified_any_options, :grep, :grep_regex

    def process
      @object_to_interrogate = args.empty? ? target_self : target.eval(args.join(" "))

      # exclude -q, -v and --grep because they don't specify what the user wants to see.
      @has_user_specified_any_options = (opts.present?(:methods) || opts.present?(:'instance-methods') || opts.present?(:ppp) ||
                                          opts.present?(:globals) || opts.present?(:locals) || opts.present?(:constants) ||
                                          opts.present?(:ivars))

      @grep_regex, @grep = [Regexp.new(opts[:G] || "."), lambda{ |x| x.grep(@grep_regex) }]

      raise_errors_if_arguments_are_weird

      all_output = [
        write_out_globals,
        write_out_constants,
        write_out_methods,
        write_out_self_methods,
        write_out_ivars,
        write_out_local_names,
        write_out_locals,
      ].compact.join("")

      stagger_output(all_output)
    end

    private

    # http://ruby.runpaint.org/globals, and running "puts global_variables.inspect".
    BUILTIN_GLOBALS = %w($" $$ $* $, $-0 $-F $-I $-K $-W $-a $-d $-i $-l $-p $-v $-w $. $/ $\\
                         $: $; $< $= $> $0 $ARGV $CONSOLE $DEBUG $DEFAULT_INPUT $DEFAULT_OUTPUT
                         $FIELD_SEPARATOR $FILENAME $FS $IGNORECASE $INPUT_LINE_NUMBER
                         $INPUT_RECORD_SEPARATOR $KCODE $LOADED_FEATURES $LOAD_PATH $NR $OFS
                         $ORS $OUTPUT_FIELD_SEPARATOR $OUTPUT_RECORD_SEPARATOR $PID $PROCESS_ID
                         $PROGRAM_NAME $RS $VERBOSE $deferr $defout $stderr $stdin $stdout)

    # $SAFE and $? are thread-local, the exception stuff only works in a rescue clause,
    # everything else is basically a local variable with a $ in its name.
    PSEUDO_GLOBALS = %w($! $' $& $` $@ $? $+ $_ $~ $1 $2 $3 $4 $5 $6 $7 $8 $9
                       $CHILD_STATUS $SAFE $ERROR_INFO $ERROR_POSITION $LAST_MATCH_INFO
                       $LAST_PAREN_MATCH $LAST_READ_LINE $MATCH $POSTMATCH $PREMATCH)

    # Get all the methods that we'll want to output
    def all_methods(obj, instance_methods=false)
      methods = if instance_methods || opts.present?(:'instance-methods')
                  Pry::Method.all_from_class(obj)
                else
                  Pry::Method.all_from_obj(obj)
                end

      if jruby? && !opts.present?(:J)
        methods = trim_jruby_aliases(methods)
      end

      methods.select{ |method| opts.present?(:ppp) || method.visibility == :public }
    end

    # JRuby creates lots of aliases for methods imported from java in an attempt to
    # make life easier for ruby programmers.
    # (e.g. getFooBar becomes get_foo_bar and foo_bar, and maybe foo_bar? if it
    # returns a Boolean).
    # The full transformations are in the assignAliases method of:
    #   https://github.com/jruby/jruby/blob/master/src/org/jruby/javasupport/JavaClass.java
    #
    # This has the unfortunate side-effect of making the output of ls even more
    # incredibly verbose than it normally would be for these objects; and so we filter
    # out all but the nicest of these aliases here.
    #
    # TODO: This is a little bit vague, better heuristics could be used.
    #       JRuby also has a lot of scala-specific logic, which we don't copy.
    #
    def trim_jruby_aliases(methods)
      grouped = methods.group_by do |m|
        m.name.sub(/\A(is|get|set)(?=[A-Z_])/, '').gsub(/[_?=]/, '').downcase
      end

      grouped.map do |key, values|
        values = values.sort_by do |m|
          rubbishness(m.name)
        end

        found = []
        values.select do |x|
          (!found.any?{ |y| x == y }) && found << x
        end
      end.flatten(1)
    end

    # When removing jruby aliases, we want to keep the alias that is "least rubbish"
    # according to this metric.
    def rubbishness(name)
      name.each_char.map{ |x|
        case x
        when /[A-Z]/
          1
        when '?', '=', '!'
          -2
        else
          0
        end
      }.inject(&:+) + (name.size / 100.0)
    end

    def resolution_order(obj)
      opts.present?(:'instance-methods') ? Pry::Method.instance_resolution_order(obj) : Pry::Method.resolution_order(obj)
    end

    # Get a lambda that can be used with .take_while to prevent over-eager
    # traversal of the Object's ancestry graph.
    def below_ceiling(obj)
      ceiling = if opts.present?(:quiet)
                   [opts.present?(:'instance-methods') ? obj.ancestors[1] : obj.class.ancestors[1]] + Pry.config.ls.ceiling
                 elsif opts.present?(:verbose)
                   []
                 else
                   Pry.config.ls.ceiling.dup
                 end

      lambda { |klass| !ceiling.include?(klass) }
    end

    def raise_errors_if_arguments_are_weird
      [
        ["-l does not make sense with a specified Object", :locals,             !args.empty?],
        ["-g does not make sense with a specified Object", :globals,            !args.empty?],
        ["-q does not make sense with -v",                 :quiet,              opts.present?(:verbose)],
        ["-M only makes sense with a Module or a Class",   :'instance-methods', !interrogating_a_module?],
        ["-c only makes sense with a Module or a Class",   :constants,          !args.empty? && !interrogating_a_module?],
      ].each do |message, option, expression|
        raise Pry::CommandError, message if opts.present?(option) && expression
      end
    end

    def interrogating_a_module?
      (Module === object_to_interrogate)
    end

    def write_out_globals
      return unless opts.present?(:globals)

      output_section("global variables", grep[format_globals(target.eval("global_variables"))])
    end

    def write_out_constants
      return unless opts.present?(:constants) || (!has_user_specified_any_options && interrogating_a_module?)

      mod = interrogating_a_module? ? object_to_interrogate : Object
      constants = WrappedModule.new(mod).constants(opts.present?(:verbose))
      output_section("constants", grep[format_constants(mod, constants)])
    end

    def write_out_methods
      return unless opts.present?(:methods) || opts.present?(:'instance-methods') || opts.present?(:ppp) || !has_user_specified_any_options

      # methods is a hash {Module/Class => [Pry::Methods]}
      methods = all_methods(object_to_interrogate).group_by(&:owner)

      output = ""
      # reverse the resolution order so that the most useful information appears right by the prompt
      resolution_order(object_to_interrogate).take_while(&below_ceiling(object_to_interrogate)).reverse.each do |klass|
        methods_here = format_methods((methods[klass] || []).select{ |m| m.name =~ grep_regex })
        output << output_section("#{Pry::WrappedModule.new(klass).method_prefix}methods", methods_here)
      end
      output
    end

    def write_out_self_methods
      return unless (!has_user_specified_any_options && interrogating_a_module?)

      methods = all_methods(object_to_interrogate, true).select{ |m| m.owner == object_to_interrogate && m.name =~ grep_regex }
      output_section("#{Pry::WrappedModule.new(object_to_interrogate).method_prefix}methods", format_methods(methods))
    end

    def write_out_ivars
      return unless opts.present?(:ivars) || !has_user_specified_any_options

      klass = (interrogating_a_module? ? object_to_interrogate : object_to_interrogate.class)
      ivars = Pry::Method.safe_send(object_to_interrogate, :instance_variables)
      kvars = Pry::Method.safe_send(klass, :class_variables)
      output_section("instance variables", format_variables(:instance_var, ivars)) +
      output_section("class variables", format_variables(:class_var, kvars))
    end

    def write_out_local_names
      return unless !has_user_specified_any_options && args.empty?

      output_section("locals", format_local_names(grep[target.eval("local_variables")]))
    end

    def write_out_locals
      return unless opts.present?(:locals)

      loc_names = target.eval('local_variables').reject do |e|
        _pry_.sticky_locals.keys.include? e.to_sym
      end
      name_value_pairs = loc_names.map do |name|
        [name, (target.eval name.to_s)]
      end
      format_locals(name_value_pairs).join("")
    end

    # Format and colourise a list of methods.
    def format_methods(methods)
      methods.sort_by(&:name).map do |method|
        if method.name == 'method_missing'
          color(:method_missing, 'method_missing')
        elsif method.visibility == :private
          color(:private_method, method.name)
        elsif method.visibility == :protected
          color(:protected_method, method.name)
        else
          color(:public_method, method.name)
        end
      end
    end

    def format_variables(type, vars)
      vars.sort_by(&:downcase).map{ |var| color(type, var) }
    end

    def format_constants(mod, constants)
      constants.sort_by(&:downcase).map do |name|
        if const = (!mod.autoload?(name) && (mod.const_get(name) || true) rescue nil)
          if (const < Exception rescue false)
            color(:exception_constant, name)
          elsif (Module === mod.const_get(name) rescue false)
            color(:class_constant, name)
          else
            color(:constant, name)
          end
        else
          color(:unloaded_constant, name)
        end
      end
    end

    def format_globals(globals)
      globals.sort_by(&:downcase).map do |name|
        if PSEUDO_GLOBALS.include?(name)
          color(:pseudo_global, name)
        elsif BUILTIN_GLOBALS.include?(name)
          color(:builtin_global, name)
        else
          color(:global_var, name)
        end
      end
    end

    def format_local_names(locals)
      locals.sort_by(&:downcase).map do |name|
        if _pry_.sticky_locals.include?(name.to_sym)
          color(:pry_var, name)
        else
          color(:local_var, name)
        end
      end
    end

    def format_locals(name_value_pairs)
      name_value_pairs.sort_by do |name, value|
        value.to_s.size
      end.reverse.map do |name, value|
        colorized_assignment_style(name, format_value(value))
      end
    end

    def colorized_assignment_style(lhs, rhs, desired_width = 7)
      colorized_lhs = color(:local_var, lhs)
      color_escape_padding = colorized_lhs.size - lhs.size
      pad = desired_width + color_escape_padding
      "%-#{pad}s = %s" % [color(:local_var, colorized_lhs), rhs]
    end

    def format_value(value)
      accumulator = StringIO.new
      Pry.output_with_default_format(accumulator, value, :hashrocket => false)
      accumulator.string
    end

    # Add a new section to the output. Outputs nothing if the section would be empty.
    def output_section(heading, body)
      return "" if body.compact.empty?
      fancy_heading = text.bold(color(:heading, heading))
      Pry::Helpers.tablify_or_one_line(fancy_heading, body)
    end

    # Color output based on config.ls.*_color
    def color(type, str)
      text.send(Pry.config.ls.send(:"#{type}_color"), str)
    end
  end

  Pry::Commands.add_command(Pry::Command::Ls)
end
