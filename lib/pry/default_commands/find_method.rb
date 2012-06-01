class Pry
  module DefaultCommands
    FindMethod = Pry::CommandSet.new do

      create_command "find-method" do
        extend Helpers::BaseHelpers

        group "Context"

        options :requires_gem => "ruby18_source_location" if mri_18?

        description "Recursively search for a method within a Class/Module or the current namespace. find-method [-n | -c] METHOD [NAMESPACE]"

        banner <<-BANNER
          Usage: find-method  [-n | -c] METHOD [NAMESPACE]

          Recursively search for a method within a Class/Module or the current namespace.
          Use the `-n` switch (the default) to search for methods whose name matches the given regex.
          Use the `-c` switch to search for methods that contain the given code.

          e.g find-method re Pry                # find all methods whose name match /re/ inside the Pry namespace. Matches Pry#repl, etc.
          e.g find-method -c 'output.puts' Pry  # find all methods that contain the code: output.puts inside the Pry namepsace.
        BANNER

        def setup
          require 'ruby18_source_location' if mri_18?
        end

        def options(opti)
          opti.on :n, :name, "Search for a method by name"
          opti.on :c, :content, "Search for a method based on content in Regex form"
        end

        def process
          return if args.size < 1
          pattern = ::Regexp.new args[0]
          if args[1]
            klass = target.eval(args[1])
            if !klass.is_a?(Module)
              klass = klass.class
            end
          else
            klass = (target_self.is_a?(Module)) ? target_self : target_self.class
          end

          matches = if opts.content?
                      content_search(pattern, klass)
                    else
                      name_search(pattern, klass)
                    end

          if matches.empty?
            output.puts text.bold("No Methods Matched")
          else
            print_matches(matches, pattern)
          end

        end

        private

        # pretty-print a list of matching methods.
        #
        # @param Array[Method]
        def print_matches(matches, pattern)
          grouped = matches.group_by(&:owner)
          order = grouped.keys.sort_by{ |x| x.name || x.to_s }

          order.each do |klass|
            output.puts text.bold(klass.name)
            grouped[klass].each do |method|
              header = method.name_with_owner

              extra = if opts.content?
                        header += ": "
                        colorize_code((method.source.split(/\n/).select {|x| x =~ pattern }).join("\n#{' ' * header.length}"))
                      else
                        ""
                      end

              output.puts header + extra
            end
          end
        end

        # Run the given block against every constant in the provided namespace.
        #
        # @param Module  The namespace in which to start the search.
        # @param Hash[Module,Boolean]  The namespaces we've already visited (private)
        # @yieldparam klazz  Each class/module in the namespace.
        #
        def recurse_namespace(klass, done={}, &block)
          return if !(Module === klass) || done[klass]

          done[klass] = true

          yield klass

          klass.constants.each do |name|
            next if klass.autoload?(name)
            begin
              const = klass.const_get(name)
            rescue RescuableException
              # constant loading is an inexact science at the best of times,
              # this often happens when a constant was .autoload? but someone
              # tried to load it. It's now not .autoload? but will still raise
              # a NameError when you access it.
            else
              recurse_namespace(const, done, &block)
            end
          end
        end

        # Gather all the methods in a namespace that pass the given block.
        #
        # @param Module  The namespace in which to search.
        # @yieldparam Method  The method to test
        # @yieldreturn Boolean
        # @return Array[Method]
        #
        def search_all_methods(namespace)
          done = Hash.new{ |h,k| h[k] = {} }
          matches = []

          recurse_namespace(namespace) do |klass|
            (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).each do |method|
              next if done[method.owner][method.name]
              done[method.owner][method.name] = true

              matches << method if yield method
            end
          end

          matches
        end

        # Search for all methods with a name that matches the given regex
        # within a namespace.
        #
        # @param Regex  The regex to search for
        # @param Module  The namespace to search
        # @return Array[Method]
        #
        def name_search(regex, namespace)
          search_all_methods(namespace) do |meth|
            meth.name =~ regex
          end
        end

        # Search for all methods who's implementation matches the given regex
        # within a namespace.
        #
        # @param Regex  The regex to search for
        # @param Module  The namespace to search
        # @return Array[Method]
        #
        def content_search(regex, namespace)
          search_all_methods(namespace) do |meth|
            begin
              meth.source =~ regex
            rescue RescuableException
              false
            end
          end
        end
      end
    end
  end
end
