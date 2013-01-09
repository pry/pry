class Pry
  class Command::Play < Pry::ClassCommand
    match 'play'
    group 'Editing'
    description 'Play back a string variable or a method or a file as input.'

    banner <<-BANNER
      Usage: play [OPTIONS] [--help]

      The play command enables you to replay code from files and methods as
      if they were entered directly in the Pry REPL. Default action (no
      options) is to play the provided string variable.

      e.g: `play --lines 149..153`
      e.g: `play -i 20 --lines 1..3`
      e.g: `play Pry#repl --lines 1..-1`
      e.g: `play Rakefile --lines 5`

      https://github.com/pry/pry/wiki/User-Input#wiki-Play
    BANNER

    def options(opt)
      CodeCollector.inject_options(opt)

      opt.on :open, "open", 'When used with the -m switch, it plays the entire method except the last line, leaving the method definition "open". `amend-line` can then be used to modify the method.'
    end

    def process
      @cc = CodeCollector.new(args, opts, _pry_)

      perform_play
      run "show-input" unless Pry::Code.complete_expression?(eval_string)
    end

    def perform_play
      eval_string << (opts.present?(:open) ? restrict_to_lines(content, (0..-2)) : content)
    end

    def content
      if args.first
        @cc.content
      else
        file_content
      end
    end

    # The file to play from when no code object is specified.
    # e.g `play --lines 4..10`
    def default_file
      target.eval("__FILE__") && File.expand_path(target.eval("__FILE__"))
    end

    def file_content
      if default_file && File.exists?(default_file)
        @cc.restrict_to_lines(File.read(default_file), @cc.line_range)
      else
        raise CommandError, "File does not exist! File was: #{default_file.inspect}"
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::Play)
end
