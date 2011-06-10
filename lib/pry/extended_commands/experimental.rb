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
          opt.banner "Usage: play [OPTIONS] [--help]\nDefault action (no options) is to play the provided string\ne.g `play puts 'hello world'` #=> \"hello world\"\ne.g `play -m Pry#repl --lines 1..-1`\ne.g `play -f Rakefile --lines 5`\n"

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true
          opt.on :f, "file", 'The line (or range of lines) to replay.', true
          opt.on :h, :help, "This message." do
            output.puts opt
          end

          opt.on_noopts { Pry.active_instance.input = StringIO.new(arg_string) }
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

          Pry.active_instance.input = StringIO.new(Array(code.each_line.to_a[range]).join)
        end

        if opts.f?
          text_array = File.readlines File.expand_path(opts[:f])
          range = opts.l? ? opts[:l] : (0..-1)

          saved_commands = Pry.active_instance.commands
          Pry.active_instance.commands = Pry::CommandSet.new
          Pry.active_instance.input = StringIO.new(Array(text_array[range]).join)
          Pry.active_instance.commands = saved_commands
        end

      end
    end
  end
end
