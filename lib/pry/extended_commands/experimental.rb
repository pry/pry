class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do


      command "reload-method", "Reload the source specifically for a method", :requires_gem => "method_reload" do |meth_name|
        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        meth.reload
      end

      command "play", "Play a string as input" do |*args|
        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: play-method [--replay START..END] [--clear] [--grep PATTERN] [--help]\n"

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true

          opt.on :f, "file", 'The line (or range of lines) to replay.', true

          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        if opts.m?
          meth_name = opts[:m]
          if (meth = get_method_object(meth_name, target, {})).nil?
            output.puts "Invalid method name: #{meth_name}."
            next
          end
          code, code_type = code_and_code_type_for(meth)
          next if !code

          range = opts.l? ? opts[:l] : (0..-1)

          Pry.active_instance.input = StringIO.new(code_join(code.each_line.to_a[range]))
        end

        if opts.f?
          text_array = File.readlines File.expand_path(opts[:f])
          range = opts.l? ? opts[:l] : (0..-1)

          Pry.active_instance.input = StringIO.new(code_join(text_array[range]))
        end

      end

      helpers do

        def code_join(arr)
          arr.map do |v|
            v.empty? ? "\n" : v
          end.join
        end

      end

    end
  end
end
