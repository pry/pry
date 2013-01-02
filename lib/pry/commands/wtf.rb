class Pry
  class Command::Wtf < Pry::ClassCommand
    match /wtf([?!]*)/
    group 'Context'
    description 'Show the backtrace of the most recent exception'
    options :listing => 'wtf?'

    banner <<-BANNER
      Show's a few lines of the backtrace of the most recent exception (also available
      as _ex_.backtrace).

      If you want to see more lines, add more question marks or exclamation marks:

      e.g.
      pry(main)> wtf?
      pry(main)> wtf?!???!?!?

      To see the entire backtrace, pass the -v/--verbose flag:

      e.g.
      pry(main)> wtf -v
    BANNER

    def options(opt)
      opt.on(:v, :verbose, "Show the full backtrace.")
    end

    def process
      raise Pry::CommandError, "No most-recent exception" unless _pry_.last_exception

      output.puts "#{text.bold('Exception:')} #{_pry_.last_exception.class}: #{_pry_.last_exception}\n--"
      if opts.verbose?
        output.puts Pry::Code.new(_pry_.last_exception.backtrace, 0, :text).with_line_numbers.to_s
      else
        output.puts Pry::Code.new(_pry_.last_exception.backtrace.first(size_of_backtrace), 0, :text).with_line_numbers.to_s
      end
    end

    private

    def size_of_backtrace
      [captures[0].size, 0.5].max * 10
  end
end

Pry::Commands.add_command(Pry::Command::Wtf)
end
