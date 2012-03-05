class Pry
  module DefaultCommands
    Hist = Pry::CommandSet.new do

      create_command "hist", "Show and replay Readline history. Aliases: history" do
        group "Editing"
        banner <<-USAGE
          Usage: hist
                 hist --head N
                 hist --tail N
                 hist --show START..END
                 hist --grep PATTERN
                 hist --clear
                 hist --replay START..END
                 hist --save [START..END] FILE
        USAGE

        def options(opt)
          opt.on :H, :head, "Display the first N items.", :optional => true, :as => Integer
          opt.on :T, :tail, "Display the last N items.", :optional => true, :as => Integer
          opt.on :s, :show, "Show the given range of lines.", :optional => true, :as => Range
          opt.on :G, :grep, "Show lines matching the given pattern.", true, :as => String
          opt.on :c, :clear, "Clear the current session's history."
          opt.on :r, :replay, "Replay a line or range of lines.", true, :as => Range
          opt.on     :save, "Save history to a file.", true, :as => Range

          opt.on :e, :'exclude-pry', "Exclude Pry commands from the history."
          opt.on :n, :'no-numbers', "Omit line numbers."
          opt.on :f, :flood, "Do not use a pager to view text longer than one screen."
        end

        def process
          @history = Pry::Code(Pry.history.to_a)

          @history = case
            when opts.present?(:head)
              @history.between(1, opts[:head] || 10)
            when opts.present?(:tail)
              @history.between(-(opts[:tail] || 10), -1)
            when opts.present?(:show)
              @history.between(opts[:show])
            else
              @history
            end

          if opts.present?(:grep)
            @history = @history.grep(opts[:grep])
          end

          if opts.present?(:'exclude-pry')
            @history = @history.select { |l, ln| !command_set.valid_command?(l) }
          end

          if opts.present?(:save)
            process_save
          elsif opts.present?(:clear)
            process_clear
          elsif opts.present?(:replay)
            process_replay
          else
            process_display
          end
        end

        def process_display
          unless opts.present?(:'no-numbers')
            @history = @history.with_line_numbers
          end

          render_output(@history, opts)
        end

        def process_save
          case opts[:save]
          when Range
            @history = @history.between(opts[:save])

            unless args.first
              raise CommandError, "Must provide a file name."
            end

            file_name = File.expand_path(args.first)
          when String
            file_name = File.expand_path(opts[:save])
          end

          output.puts "Saving history in #{file_name}..."

          File.open(file_name, 'w') { |f| f.write(@history.raw) }

          output.puts "History saved."
        end

        def process_clear
          Pry.history.clear
          output.puts "History cleared."
        end

        def process_replay
          @history = @history.between(opts[:r])

          _pry_.input_stack.push _pry_.input
          _pry_.input = StringIO.new(@history.raw)
          # eval_string << "#{@history.raw}\n"
          # run "show-input" unless _pry_.complete_expression?(eval_string)
        end
      end

      alias_command "history", "hist"




    end
  end
end
