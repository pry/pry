class Pry
  module DefaultCommands

    Ls = Pry::CommandSet.new do

      create_command "ls","Show the list of vars and methods in the current scope.",
      :shellwords => false, :interpolate => false do

        group "Context"

        def options(opt)
          opt.banner unindent <<-USAGE
            Usage: ls [-m|-M|-p|-pM] [-q|-v] [-c|-i] [Object]
                   ls [-g] [-l]

            ls shows you which methods, constants and variables are accessible to Pry. By default it shows you the local variables defined in the current shell, and any public methods or instance variables defined on the current object.

            The colours used are configurable using Pry.config.ls.*_color, and the separator is Pry.config.ls.separator.

            Pry.config.ls.ceiling is used to hide methods defined higher up in the inheritance chain, this is by default set to [Object, Module, Class] so that methods defined on all Objects are omitted. The -v flag can be used to ignore this setting and show all methods, while the -q can be used to set the ceiling much lower and show only methods defined on the object or its direct class.
          USAGE

          opt.on :m, "methods", "Show public methods defined on the Object (default)"
          opt.on :M, "instance-methods", "Show methods defined in a Module or Class"

          opt.on :p, "ppp", "Show public, protected (in yellow) and private (in green) methods"
          opt.on :q, "quiet", "Show only methods defined on object.singleton_class and object.class"
          opt.on :v, "verbose", "Show methods and constants on all super-classes (ignores Pry.config.ls.ceiling)"

          opt.on :g, "globals", "Show global variables, including those builtin to Ruby (in cyan)"
          opt.on :l, "locals", "Show locals, including those provided by Pry (in red)"

          opt.on :c, "constants", "Show constants, highlighting classes (in blue), and exceptions (in purple)"

          opt.on :i, "ivars", "Show instance variables (in blue) and class variables (in bright blue)"

          opt.on :G, "grep", "Filter output by regular expression", :optional => false
        end

        def process
          obj = args.empty? ? target_self : target.eval(args.join(" "))

          # exclude -q, -v and --grep because they don't specify what the user wants to see.
          has_opts = (opts.present?(:methods) || opts.present?(:'instance-methods') || opts.present?(:ppp) ||
                      opts.present?(:globals) || opts.present?(:locals) || opts.present?(:constants) ||
                      opts.present?(:ivars))

          show_methods   = opts.present?(:methods) || opts.present?(:'instance-methods') || opts.present?(:ppp) || !has_opts
          show_constants = opts.present?(:constants) || (!has_opts && Module === obj)
          show_ivars     = opts.present?(:ivars) || !has_opts
          show_locals    = opts.present?(:locals) || (!has_opts && args.empty?)

          grep_regex, grep = [Regexp.new(opts[:G] || "."), lambda{ |x| x.grep(grep_regex) }]

          raise Pry::CommandError, "-l does not make sense with a specified Object" if opts.present?(:locals) && !args.empty?
          raise Pry::CommandError, "-g does not make sense with a specified Object" if opts.present?(:globals) && !args.empty?
          raise Pry::CommandError, "-q does not make sense with -v" if opts.present?(:quiet) && opts.present?(:verbose)
          raise Pry::CommandError, "-M only makes sense with a Module or a Class" if opts.present?(:'instance-methods') && !(Module === obj)
          raise Pry::CommandError, "-c only makes sense with a Module or a Class" if opts.present?(:constants) && !args.empty? && !(Module === obj)


          if opts.present?(:globals)
            output_section("global variables", grep[format_globals(target.eval("global_variables"))])
          end

          if show_constants
            mod = Module === obj ? obj : Object
            constants = mod.constants
            constants -= (mod.ancestors - [mod]).map(&:constants).flatten unless opts.present?(:verbose)
            output_section("constants", grep[format_constants(mod, constants)])
          end

          if show_methods
            # methods is a hash {Module/Class => [Pry::Methods]}
            methods = all_methods(obj).select{ |method| opts.present?(:ppp) || method.visibility == :public }.group_by(&:owner)

            # reverse the resolution order so that the most useful information appears right by the prompt
            resolution_order(obj).take_while(&below_ceiling(obj)).reverse.each do |klass|
              methods_here = format_methods((methods[klass] || []).select{ |m| m.name =~ grep_regex })
              output_section "#{Pry::WrappedModule.new(klass).method_prefix}methods", methods_here
            end
          end

          if show_ivars
            klass = (Module === obj ? obj : obj.class)
            output_section("instance variables", format_variables(:instance_var, grep[obj.__send__(:instance_variables)]))
            output_section("class variables", format_variables(:class_var, grep[klass.__send__(:class_variables)]))
          end

          if show_locals
            output_section("locals", format_locals(grep[target.eval("local_variables")]))
          end
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
        def all_methods(obj)
          opts.present?(:'instance-methods') ? Pry::Method.all_from_class(obj) : Pry::Method.all_from_obj(obj)
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
            if const = (!mod.autoload?(name) && mod.const_get(name) rescue nil)
              if (const < Exception rescue false)
                color(:exception_constant, name)
              elsif (Module === mod.const_get(name) rescue false)
                color(:class_constant, name)
              else
                color(:constant, name)
              end
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

        def format_locals(locals)
          locals.sort_by(&:downcase).map do |name|
            if _pry_.sticky_locals.include?(name.to_sym)
              color(:pry_var, name)
            else
              color(:local_var, name)
            end
          end
        end

        # Add a new section to the output. Outputs nothing if the section would be empty.
        def output_section(heading, body)
          return if body.compact.empty?
          output.puts "#{text.bold(color(:heading, heading))}: #{body.compact.join(Pry.config.ls.separator)}"
        end

        # Color output based on config.ls.*_color
        def color(type, str)
          text.send(Pry.config.ls.send(:"#{type}_color"), str)
        end
      end
    end
  end
end
