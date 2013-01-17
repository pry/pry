class Pry
  class Command::Gist < Pry::ClassCommand
    match 'gist'
    group 'Misc'
    description 'Playback a string variable or a method or a file as input.'
    command_options :requires_gem => "jist"

    banner <<-'BANNER'
      Usage: gist [OPTIONS] [--help]

      The gist command enables you to gist code from files and methods to github.

      gist -i 20 --lines 1..3
      gist Pry#repl --lines 1..-1
      gist Rakefile --lines 5
    BANNER

    def setup
      require 'jist'
    end

    def options(opt)
      CodeCollector.inject_options(opt)
      opt.on :login, "Authenticate the jist gem with GitHub"
      opt.on :p, :public, "Create a public gist (default: false)", :default => false
      opt.on :clip, "Copy the selected content to clipboard instead, do NOT gist it", :default => false
    end

    def process
      return Jist.login! if opts.present?(:login)
      cc = CodeCollector.new(args, opts, _pry_)

      if cc.content =~ /\A\s*\z/
        raise CommandError, "Found no code to gist."
      end

      if opts.present?(:clip)
        clipboard_content(cc.content)
      else
        # we're overriding the default behavior of the 'in' option (as
        # defined on CodeCollector) with our local behaviour.
        content = opts.present?(:in) ? input_content : cc.content
        gist_content content, cc.file
      end
    end

    def clipboard_content(content)
      Jist.copy(content)
      output.puts "Copied content to clipboard!"
    end

    def input_content
      content = ""
      CodeCollector.input_expression_ranges.each do |range|
        input_expressions = _pry_.input_array[range] || []
        Array(input_expressions).each_with_index do |code, index|
          corrected_index = index + range.first
          if code && code != ""
            content << code
            if code !~ /;\Z/
              content << "#{comment_expression_result_for_gist(Pry.config.gist.inspecter.call(_pry_.output_array[corrected_index]))}"
            end
          end
        end
      end

      content
    end

    def comment_expression_result_for_gist(result)
      content = ""
      result.lines.each_with_index do |line, index|
        if index == 0
          content << "# => #{line}"
        else
          content << "#    #{line}"
        end
      end

      content
    end

    def gist_content(content, filename)
      response = Jist.gist(content, :filename => filename || "pry_gist.rb", :public => !!opts[:p])
      if response
        url = response['html_url']
        message = "Gist created at URL #{url}"
        begin
          Jist.copy(url)
          message << ", which is now in the clipboard."
        rescue Jist::ClipboardError
        end

        output.puts message
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::Gist)
  Pry::Commands.alias_command 'clipit', 'gist --clip'
  Pry::Commands.alias_command 'jist', 'gist'
end
