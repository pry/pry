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
        Slop.parse!(args) do |opt|
          opt.banner "Usage: play-method [--replay START..END] [--clear] [--grep PATTERN] [--help]\n"

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :m, :method, 'Play a method.', true do |meth_name|
            if (meth = get_method_object(meth_name, target, {})).nil?
              output.puts "Invalid method name: #{meth_name}."
              next
            end
            code, code_type = code_and_code_type_for(meth)
            next if !code

            range = opt.l? ? opt[:l] : (0..-1)

            Pry.active_instance.input = StringIO.new(code[range])
          end

          opt.on :f, "file", 'The line (or range of lines) to replay.', true do |file_name|
            text = File.read File.expand_path(file_name)
            range = opt.l? ? opt[:l] : (0..-1)

            Pry.active_instance.input = StringIO.new(text[range])
          end

          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end
      end
    end
  end
end
