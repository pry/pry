class Pry
  module DefaultCommands
    FindMethod = Pry::CommandSet.new do

      create_command "find-method" do
        extend Helpers::BaseHelpers

        group "Context"

        options :requires_gem => "ruby18_source_location" if mri_18?

        description "Recursively search for a method within a Class/Module or the current namespace. find-method [-n | -c] METHOD [NAMESPACE]"


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
          if opts.name?
            to_put = name_search(pattern, klass)
          elsif opts.content?
            to_put = content_search(pattern, klass)
          else
            to_put = name_search(pattern, klass)
          end
          1
          if to_put.flatten == []
            puts text.bold("No Methods Matched")
          else
            puts text.bold("Methods Matched")
            puts "--"
            stagger_output to_put.join("\n")
          end

        end

        private

        def puts(item)
          output.puts item
        end

        def content_search(pattern, klass, current=[], the_methods=[])
          return unless(klass.is_a? Module)
          return if current.include? klass
          current << klass
          meths = []
          (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each do |meth|
            next if the_methods.include? meth.name
            the_methods << meth.name
            begin
              if meth.source =~ pattern && !meth.alias?
                header = "#{klass}##{meth.name}:  "
                meths <<  header + colorize_code((meth.source.split(/\n/).select {|x| x =~ pattern }).join("\n#{' ' * header.length}"))
              end
            rescue Pry::RescuableException
              next
            rescue Pry::CommandError
              next
            end
          end
          klass.constants.each do |klazz|
            begin
              meths += ((res = content_search(pattern, klass.const_get(klazz), current, the_methods)) ? res : [])
            rescue Pry::RescuableException
              next
            end
          end
          return meths.uniq.flatten
        end

        def name_search(regex, klass, current=[], the_methods=[])
          return unless(klass.is_a? Module)
          return if current.include? klass
          current << klass
          header = text.bold("#{klass.name}:")
          meths = []
          (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each do |x|
            next if the_methods.include? x.name
            the_methods << x.name
            if x.name =~ regex
              meths << "   #{x.name}"
              begin
                if x.alias?
                  meths[-1] += "#A|#{x.original_name}" if x.original_name
                end
              rescue Pry::RescuableException
              end
            end
          end
          max = meths.map(&:length).max
          meths.map! do |x|
            if x =~ /#{"#A"}/
              x = x.sub!("#A|", ((' ' * ((max - x.length) + 3)) + text.bold("(Alias of "))) + text.bold(")")
            end
            x
          end
          meths.unshift header if meths.size > 0
          klass.constants.each do |x|
            begin
              meths << ((res = name_search(regex, klass.const_get(x), current, the_methods)) ? res : [])
            rescue Pry::RescuableException
              next
            end
          end
          return meths.uniq.flatten
        end
      end
    end
  end
end
