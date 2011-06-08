class Pry
  module DefaultCommands

    Ls = Pry::CommandSet.new do

      command "ls", "Show the list of vars and methods in the current scope. Type `ls --help` for more info." do |*args|
        options = {}
        # Set target local to the default -- note that we can set a different target for
        # ls if we like: e.g ls my_var
        target = target()

        OptionParser.new do |opts|
          opts.banner = %{Usage: ls [OPTIONS] [VAR]\n\
List information about VAR (the current context by default).
Shows local and instance variables by default.
--
}
          opts.on("-g", "--globals", "Display global variables.") do
            options[:g] = true
          end

          opts.on("-c", "--constants", "Display constants.") do
            options[:c] = true
          end

          opts.on("-l", "--locals", "Display locals.") do
            options[:l] = true
          end

          opts.on("-i", "--ivars", "Display instance variables.") do
            options[:i] = true
          end

          opts.on("-k", "--class-vars", "Display class variables.") do
            options[:k] = true
          end

          opts.on("-m", "--methods", "Display methods (public methods by default).") do
            options[:m] = true
          end

          opts.on("-M", "--instance-methods", "Display instance methods (only relevant to classes and modules).") do
            options[:M] = true
          end

          opts.on("-P", "--public", "Display public methods (with -m).") do
            options[:P] = true
          end

          opts.on("-r", "--protected", "Display protected methods (with -m).") do
            options[:r] = true
          end

          opts.on("-p", "--private", "Display private methods (with -m).") do
            options[:p] = true
          end

          opts.on("-j", "--just-singletons", "Display just the singleton methods (with -m).") do
            options[:j] = true
          end

          opts.on("-s", "--super", "Include superclass entries (relevant to constant and methods options).") do
            options[:s] = true
          end

          opts.on("-a", "--all", "Display all types of entries.") do
            options[:a] = true
          end

          opts.on("-v", "--verbose", "Verbose ouput.") do
            options[:v] = true
          end

          opts.on("-f", "--flood", "Do not use a pager to view text longer than one screen.") do
            options[:f] = true
          end

          opts.on("--grep REG", "Regular expression to be used.") do |reg|
            options[:grep] = Regexp.new(reg)
          end

          opts.on_tail("-h", "--help", "Show this message.") do
            output.puts opts
            options[:h] = true
          end
        end.order(args) do |new_target|
          target = Pry.binding_for(target.eval("#{new_target}")) if !options[:h]
        end

        # exit if we've displayed help
        next if options[:h]

        # default is locals/ivars/class vars.
        # Only occurs when no options or when only option is verbose
        options.merge!({
                         :l => true,
                         :i => true,
                         :k => true
                       }) if options.empty? || (options.size == 1 && options[:v]) || (options.size == 1 && options[:grep])

        options[:grep] = // if !options[:grep]


                              # Display public methods by default if -m or -M switch is used.
                              options[:P] = true if (options[:m] || options[:M]) && !(options[:p] || options[:r] || options[:j])

                              info = {}
                              target_self = target.eval('self')

                              # ensure we have a real boolean and not a `nil` (important when
                              # interpolating in the string)
                              options[:s] = !!options[:s]

                              # Numbers (e.g 0, 1, 2) are for ordering the hash values in Ruby 1.8
                              i = -1

                              # Start collecting the entries selected by the user
                              info["local variables"] = [Array(target.eval("local_variables")).sort, i += 1] if options[:l] || options[:a]
                              info["instance variables"] = [Array(target.eval("instance_variables")).sort, i += 1] if options[:i] || options[:a]

                              info["class variables"] = [if target_self.is_a?(Module)
                                                           Array(target.eval("class_variables")).sort
                                                         else
                                                           Array(target.eval("self.class.class_variables")).sort
                                                         end, i += 1] if options[:k] || options[:a]

                              info["global variables"] = [Array(target.eval("global_variables")).sort, i += 1] if options[:g] || options[:a]

                              info["public methods"] = [Array(target.eval("public_methods(#{options[:s]})")).uniq.sort, i += 1] if (options[:m] && options[:P]) || options[:a]

                              info["protected methods"] = [Array(target.eval("protected_methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:r]) || options[:a]

                              info["private methods"] = [Array(target.eval("private_methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:p]) || options[:a]

                              info["just singleton methods"] = [Array(target.eval("methods(#{options[:s]})")).sort, i += 1] if (options[:m] && options[:j]) || options[:a]

                              info["public instance methods"] = [Array(target.eval("public_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:P]) || options[:a])

                              info["protected instance methods"] = [Array(target.eval("protected_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:r]) || options[:a])

                              info["private instance methods"] = [Array(target.eval("private_instance_methods(#{options[:s]})")).uniq.sort, i += 1] if target_self.is_a?(Module) && ((options[:M] && options[:p]) || options[:a])

                              # dealing with 1.8/1.9 compatibility issues :/
                              csuper = options[:s]
                              if Module.method(:constants).arity == 0
                                csuper = nil
                              end

                              info["constants"] = [Array(target_self.is_a?(Module) ? target.eval("constants(#{csuper})") :
                                                         target.eval("self.class.constants(#{csuper})")).uniq.sort, i += 1] if options[:c] || options[:a]

                              text = ""

                              # verbose output?
                              if options[:v]
                                # verbose

                                info.sort_by { |k, v| v.last }.each do |k, v|
              if !v.first.empty?
                text <<  "#{k}:\n--\n"
                filtered_list = v.first.grep options[:grep]
                if Pry.color
                  text << CodeRay.scan(Pry.view(filtered_list), :ruby).term + "\n"
                else
                  text << Pry.view(filtered_list) + "\n"
                end
                text << "\n\n"
              end
            end

                                if !options[:f]
                                  stagger_output(text)
                                else
                                  output.puts text
                                end

                                # plain
                              else
                                list = info.values.sort_by(&:last).map(&:first).inject(&:+)
                                list = list.grep(options[:grep]) if list
                                list.uniq! if list
                                if Pry.color
                                  text << CodeRay.scan(list.inspect, :ruby).term + "\n"
                                else
                                  text <<  list.inspect + "\n"
                                end
                                if !options[:f]
                                  stagger_output(text)
                                else
                                  output.puts text
                                end
                                list
                              end
                            end


    end
  end
end
