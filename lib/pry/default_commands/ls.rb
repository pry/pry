class Pry
  module DefaultCommands

    Ls = Pry::CommandSet.new do

      helpers do

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
        def all_methods(obj, opts)
          opts.M? ? Pry::Method.all_from_class(obj) : Pry::Method.all_from_obj(obj)
        end

        def singleton_class(obj); class << obj; self; end end

        def resolution_order(obj, opts)
          opts.M? ? Pry::Method.instance_resolution_order(obj) : Pry::Method.resolution_order(obj)
        end

        # Get the name of the klass for pretty display in the title column of ls -m
        # as there can only ever be one singleton class of a non-class, we just call
        # that "self".
        def class_name(klass)
          if klass == klass.ancestors.first
            (klass.name || "") == "" ? klass.to_s : klass.name
          elsif klass.ancestors.include?(Module)
            begin
              "#{class_name(ObjectSpace.each_object(klass).detect{ |x| singleton_class(x) == klass })}.self"
            rescue # ObjectSpace is not enabled by default in jruby
              klass.to_s.sub(/#<(Module|Class):(.*)>/, '\2.self')
            end
          else
            "self"
          end
        end

        # Get a lambda that can be used with .take_while to prevent over-eager
        # traversal of the Object's ancestry graph.
        def below_ceiling(obj, opts)
          ceiling = if opts.q?
                       [opts.M? ? obj.ancestors[1] : obj.class.ancestors[1]] + [Object, Module, Class]
                     elsif opts.v?
                       []
                     else
                       [Module, Object, Class] #TODO: make configurable
                     end

          # We always want to show *something*, so if this object is actually a base type,
          # then we'll show the class itself, but none of its ancestors nor modules.
          ceiling.map!{ |klass| (obj.class == klass || obj == klass) ? klass.ancestors[1] : klass }

          lambda { |klass| !ceiling.include?(klass) }
        end

        # Format and colourise a list of methods.
        def format_methods(methods)
          methods.sort_by(&:name).map do |method|
            if method.name == 'method_missing'
              text.red('method_missing') # This should stand out!
            elsif method.visibility == :private
              text.green(method.name) # TODO: make colours configurable
            elsif method.visibility == :protected
              text.yellow(method.name)
            else
              method.name
            end
          end.join("  ")
        end

        def output_variables(type, vars)
          vars = vars.sort_by(&:downcase).join("  ")
          output_section(type, text.send(ls_color_map[type], vars)) if vars.strip != ""
        end

        def format_constants(mod, constants)
          constants.sort_by(&:downcase).map do |name|
            if const = (mod.const_get(name) rescue nil)
              if (const < Exception rescue false)
                text.purple(name)
              elsif (Module === mod.const_get(name) rescue false)
                text.blue(name)
              else
                name
              end
            end
          end.compact.join("  ")
        end

        def format_globals(globals, quiet)
          globals.sort_by(&:downcase).map do |name|
            if PSEUDO_GLOBALS.include?(name)
              text.cyan(name) unless quiet
            elsif BUILTIN_GLOBALS.include?(name)
              text.cyan(name) unless quiet
            else
              name
            end
          end.compact.join("  ")
        end

        def format_locals(locals)
          locals.sort_by(&:downcase).map do |name|
            if _pry_.special_locals.include?(name.to_sym)
              text.red(name)
            else
              name
            end
          end.join(" ")
        end

        # Add a new section to the output. Outputs nothing if the section would be empty.
        def output_section(heading, body)
          output.puts "#{text.bold(text.grey(heading))}: #{body}" if body.strip != ""
        end

        def ls_color_map
          {
            "local variables" => Pry.config.ls.local_var_color,                   #black
            "pry variables" => Pry.config.pry_var_color,                          #red

            "instance variables" => Pry.config.ls.instance_var_color,             #blue
            "class variables" => Pry.config.ls.class_var_color,                   #bright_blue

            "global variables" => Pry.config.ls.global_var_color,                 #black
            "pseudo-global variables" => Pry.config.ls.pseudo_global_var_color,   #cyan
            "builtin global variables" => Pry.config.ls.builtin_global_var_color, #cyan

            "public methods" => Pry.config.ls.public_color,                       #black
            "private methods" => Pry.config.ls.private_color,                     #green
            "protected methods" => Pry.config.ls.protected_color,                 #yellow
            "method_missing" => Pry.config.ls.method_missing_color,               #red

            "class constants" => Pry.config.ls.constant_color,                    #blue
            "exception constants" => Pry.config.ls.class_color,                   #magenta
            "other constants" => Pry.config.ls.exception_color                    #black
          }
        end
      end

      command "ls", "Show the list of vars and methods in the current scope. Type `ls --help` for more info.",
              :shellwords => false, :interpolate => false do |*args|

        # have we been passed any options about what to show (exclude q and v because they're just tweaks)
        has_opts = args.first && args.any?{ |arg| arg.start_with?("-") && arg.tr("-qv", "") != "" }

        opts = Slop.parse!(args, :strict => true) do |opt|
          opt.banner unindent <<-USAGE
            Usage: ls [-m|-M] [-p] [-q|-v] [-g] [-l] [-c] [-i] [Object]

            ls shows you which methods, constants and variables are accessible to Pry. By default it shows you
            the local variables defined in the current shell, and any public methods or instance variables defined
            on the current object.

            The -c flag lists constants, either in the top-level if given no argument or in the namespace that you
            specify. Exceptions are coloured purple, other Classes are blue and anything else is black.

            The -m flag lists methods defined on an object, while the -M flag lists methods defined in a class. In
            both cases the -p flag shows private methods (in blue) and protected methods (in purple).

            The -v flag can be used to show all methods and constants. By default methods and constants available
            on all objects are not shown. The -q flag removes more methods, only displaying those

          USAGE

          opt.on :m, "methods", "Show public methods defined on the Object"
          opt.on :M, "module", "Show methods defined in a Module or Class"

          opt.on :p, "ppp", "Show public, protected and private methods (by default only public methods are shown)"
          opt.on :q, "quiet", "Show only methods defined on object.singleton_class and object.class (See Pry.config.ls_ceiling)"
          opt.on :v, "verbose", "Show methods on all super-classes (ignores Pry.config.ls_ceiling)"

          opt.on :g, "globals", "Show globals"
          opt.on :l, "locals", "Show locals"
          opt.on :c, "constants", "Show constants"
          opt.on :i, "ivars", "Show instance and class variables"

          opt.on :h, "help", "Show help"
        end

        next output.puts(opts) if opts.h?

        obj = args.empty? ? target_self : target.eval(args.join(" "))
        show_methods   = opts.m? || opts.M? || opts.p? || !has_opts
        show_constants = opts.c? || (!has_opts && (Module === obj || TOPLEVEL_BINDING.eval('self') == obj))
        show_ivars     = opts.i? || !has_opts
        show_locals    = opts.l? || (!has_opts && args.empty?)

        raise Pry::CommandError, "-l does not make sense with a specified Object" if opts.l? && !args.empty?
        raise Pry::CommandError, "-g does not make sense with a specified Object" if opts.g? && !args.empty?
        raise Pry::CommandError, "-q does not make sense with -v" if opts.q? && opts.v?
        raise Pry::CommandError, "-M only makes sense with a Module or a Class" if opts.M? && !(Module === obj)
        raise Pry::CommandError, "-c only makes sense with a Module or a Class" if opts.c? && !args.empty? && !(Module === obj)

        if opts.g?
          output_section("global variables", format_globals(target.eval("global_variables"), opts.q?))
        end

        if show_constants
          mod = Module === obj ? obj : Object
          constants = mod.constants
          constants -= (mod.ancestors - [mod]).map(&:constants).flatten unless opts.v?
          output_section("constants", format_constants(mod, constants))
        end

        if show_methods
          # methods is a hash {Module/Class => [Pry::Methods]}
          methods = all_methods(obj, opts).select{ |method| opts.p? || method.visibility == :public }.group_by(&:owner)

          # reverse the resolution order so that the most useful information appears right by the prompt
          resolution_order(obj, opts).take_while(&below_ceiling(obj, opts)).reverse.each do |klass|
            output_section "#{class_name(klass)} methods", format_methods(methods[klass] || [])
          end
        end

        if show_ivars
          output_variables("instance variables", obj.__send__(:instance_variables))
          output_variables("class variables", (Module === obj ? obj : obj.class).__send__(:class_variables))
        end

        if show_locals
          output_section("locals", format_locals(target.eval("local_variables")))
        end
      end
    end
  end
end
