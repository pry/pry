class Pry
  module DefaultCommands
    FindMethod = Pry::CommandSet.new do
        
        
        create_command "find-method" do   
            
            group "Context"
            
            description "Recursively search for a method within a Class/Module or the current namespace. find-method [-n | -c] METHOD [NAMESPACE]"
            
            def options(opti)
                opti.on :n, :name, "Search for a method by name"
                opti.on :c, :content, "Search for a method based on content in Regex form"
            end
            
            def process
                return if args.size < 1
                pattern = ::Regexp.new args[0]
                if args[1]
                    if target.eval(args[1]).is_a?(Module)
                        klass   = target.eval args[1]
                    else
                        klass = target.eval(args[1]).class
                    end
                else    
                    to_put = target_self_eval(pattern, opts)
                    if to_put.flatten == []
                        puts "\e[31;1mNo Methods Found\e[0m"
                    else
                        puts "\e[32;1;4mMethods Found\e[0m"
                        puts to_put
                    end
                    return
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
                    puts "\e[31;1mNo Methods Found\e[0m"
                else
                    puts "\e[1;4;32mMethods Found\e[0m"
                    puts to_put
                end

            end
            
            private

            def puts(item)
                output.puts item
            end
            
            def target_self_eval(pattern, opts)
                obj = target_self
                if opts.name?
                    return (obj.methods.select {|x| x=~pattern}).map {|x| "(#{obj.to_s})##{x}" }
                elsif opts.content?
                    ret = []
                    obj.methods.select do |x|
                        meth = Pry::Method.new obj.method(x)
                        if meth.source =~ pattern
                            ret << "(#{obj.to_s})##{x}: " + (meth.source.split(/\n/).select {|x| x =~ pattern }).join("\n\t")
                        end
                    end
                    return ret
                else
                    return (obj.methods.select {|x| x=~pattern}).map {|x| "(#{obj.to_s})##{x}" }
                end  
            end

            def content_search(pattern, klass, current=[])
                return unless(klass.is_a? Module)
                return if current.include? klass
                current << klass
                meths = []
                (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each do |meth|
                begin
                    if meth.source =~ pattern && !meth.alias?
                        meths << "#{klass}##{meth.name}: " + (meth.source.split(/\n/).select {|x| x =~ pattern }).join("\n\t")
                    end
                rescue Exception
                    next
                end
                end
                klass.constants.each do |klazz|
                    meths += ((res = content_search(pattern, klass.const_get(klazz), current)) ? res : [])
                end
                return meths.flatten
            end
                    
            def name_search(regex, klass, current=[])
                return unless(klass.is_a? Module)
                return if current.include? klass
                current << klass
                meths = []
                (Pry::Method.all_from_class(klass) + Pry::Method.all_from_obj(klass)).uniq.each {|x| meths << "#{klass}##{x.name}" if x.name =~ regex }
                klass.constants.each do |x|
                    meths += ((res = name_search(regex, klass.const_get(x), current)) ? res : [])
                end
                return meths.flatten
            end 
            
        end
    end
  end
end