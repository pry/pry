class Pry
  class Command::Whereami < Pry::ClassCommand
    match 'whereami'
    description 'Show code surrounding the current context.'
    group 'Context'

    banner <<-'BANNER'
      Usage: whereami [-qn] [N]

      Describe the current location. If you use `binding.pry` inside a method then
      whereami will print out the source for that method.

      If a number is passed, then N lines before and after the current line will be
      shown instead of the method itself.

      The `-q` flag can be used to suppress error messages in the case that there's
      no code to show. This is used by pry in the default before_session hook to show
      you when you arrive at a `binding.pry`.

      The `-n` flag can be used to hide line numbers so that code can be copy/pasted
      effectively.

      When pry was started on an Object and there is no associated method, whereami
      will instead output a brief description of the current object.
    BANNER

    def setup
      @method = Pry::Method.from_binding(target)
      @file = target.eval('__FILE__')
      @line = target.eval('__LINE__')
    end

    def options(opt)
      opt.on :q, :quiet,             "Don't display anything in case of an error"
      opt.on :n, :"no-line-numbers", "Do not display line numbers"
    end

    def code
      @code ||= if show_method?
                  Pry::Code.from_method(@method)
                else
                  Pry::Code.from_file(@file).around(@line, window_size)
                end
    end

    def location
      "#{@file} @ line #{@line} #{@method && @method.name_with_owner}"
    end

    def process
      if nothing_to_do?
        return
      elsif internal_binding?(target)
        handle_internal_binding
        return
      end

      set_file_and_dir_locals(@file)

      output.puts "\n#{text.bold('From:')} #{location}:\n\n"
      output.puts code.with_line_numbers(use_line_numbers?).with_marker(marker)
      output.puts
    end

    private

    def nothing_to_do?
      opts.quiet? && (internal_binding?(target) || !code?)
    end

    def use_line_numbers?
      !opts.present?(:n)
    end

    def marker
      !opts.present?(:n) && @line
    end

    def top_level?
      target_self == TOPLEVEL_BINDING.eval("self")
    end

    def handle_internal_binding
      if top_level?
        output.puts "At the top level."
      else
        output.puts "Inside #{Pry.view_clip(target_self)}."
      end
    end

    def show_method?
      args.empty? && @method && @method.source? && @method.source_range.count < 20 &&
      # These checks are needed in case of an eval with a binding and file/line
      # numbers set to outside the function. As in rails' use of ERB.
      @method.source_file == @file && @method.source_range.include?(@line)
    end

    def code?
      !!code
    rescue MethodSource::SourceNotFoundError
      false
    end

    def window_size
      if args.empty?
        Pry.config.default_window_size
      else
        args.first.to_i
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::Whereami)
end
