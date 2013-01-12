class Pry
  class Command::Play < Pry::ClassCommand
    match 'play'
    group 'Editing'
    description 'Playback a string variable or a method or a file as input.'

    banner <<-'BANNER'
      Usage: play [OPTIONS] [--help]

      The play command enables you to replay code from files and methods as if they
      were entered directly in the Pry REPL.

      play --lines 149..153
      play -i 20 --lines 1..3
      play Pry#repl --lines 1..-1
      play Rakefile --lines 5

      https://github.com/pry/pry/wiki/User-Input#wiki-Play
    BANNER

    def options(opt)
      CodeCollector.inject_options(opt)

      opt.on :open, 'Plays the select content except except' \
                    ' the last line. Useful for replaying methods and leaving the method definition "open". `amend-line`' \
                    ' can then be used to modify the method.'
    end

    def process
      @cc = CodeCollector.new(args, opts, _pry_)

      perform_play
      run "show-input" unless Pry::Code.complete_expression?(eval_string)
    end

    def perform_play
      eval_string << (opts.present?(:open) ? restrict_to_lines(content, (0..-2)) : content)
      run "fix-indent"
    end

    def should_use_default_file?
      !args.first && !opts.present?(:in) && !opts.present?(:out)
    end

    def content
      if should_use_default_file?
        file_content
      else
        @cc.content
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
