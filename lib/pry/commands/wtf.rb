# frozen_string_literal: true

class Pry
  class Command
    class Wtf < Pry::ClassCommand
      match(/wtf([?!]*)/)
      group 'Context'
      description 'Show the backtrace of the most recent exception.'
      options listing: 'wtf?'

      banner <<-'BANNER'
        Usage: wtf[?|!]

        Shows a few lines of the backtrace of the most recent exception (also available
        as `_ex_.backtrace`). If you want to see more lines, add more question marks or
        exclamation marks.

        wtf?
        wtf?!???!?!?

        # To see the entire backtrace, pass the `-v` or `--verbose` flag.
        wtf -v
      BANNER

      def options(opt)
        opt.on :v, :verbose, "Show the full backtrace"
      end

      def process
        unless pry_instance.last_exception
          raise Pry::CommandError, "No most-recent exception"
        end

        text = ''.dup
        unwind_exceptions.each_with_index do |exception, i|
          title = (i == 0 ? 'Exception' : 'Caused by')
          text << format_header(title, exception)
          text << format_backtrace(exception.backtrace)
        end
        output.puts(text)
      end

      private

      def unwind_exceptions
        exception_list = []
        exception = pry_instance.last_exception

        while exception
          exception_list << exception
          exception = (exception.cause if exception.respond_to?(:cause))
        end

        exception_list
      end

      def format_header(title, exception)
        "#{bold(title + ':')} #{exception.class}: #{exception}\n--\n"
      end

      def format_backtrace(backtrace)
        return with_line_numbers(backtrace) if opts.verbose?

        size_of_backtrace = [captures[0].size, 0.5].max * 10
        with_line_numbers(backtrace.first(size_of_backtrace))
      end

      def with_line_numbers(backtrace)
        Pry::Code.new(backtrace, 0, :text).with_line_numbers.to_s
      end
    end

    Pry::Commands.add_command(Pry::Command::Wtf)
  end
end
