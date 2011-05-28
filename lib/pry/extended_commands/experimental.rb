class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do


      command /rue-(\d)/, "Experimental amend-line, where the N in rue-N represents line to replace", :interpolate => false do |replacement_line|
        replacement_line = "" if !replacement_line
        input_array = opts[:eval_string].each_line.to_a
        line_number = opts[:captures].first.to_i
        input_array[line_number] = opts[:arg_string] + "\n"
        opts[:eval_string].replace input_array.join
      end


      command "play-string", "Play a string as input" do
        Pry.active_instance.input = StringIO.new(opts[:arg_string])
      end

      command "play-method", "Play a method source as input" do |*args|
        target = target()
        opts = Slop.parse!(args) do |opt|
          opt.banner "Usage: play-method [--replay START..END] [--clear] [--grep PATTERN] [--help]\n"

          opt.on :l, :lines, 'The line (or range of lines) to replay.', true, :as => Range
          opt.on :h, :help, "This message." do
            output.puts opt
          end
        end

        next if opts.help?

        meth_name = args.shift
        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}. Type `play-method --help` for help"
          next
        end

        code, code_type = code_and_code_type_for(meth)
        next if !code

        slice = opts[:l] ? opts[:l] : (0..-1)

        sliced_code = code.each_line.to_a[slice].join("\n")

        Pry.active_instance.input = StringIO.new(sliced_code)
      end

    end
  end
end
