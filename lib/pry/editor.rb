class Pry
  class Editor
    extend Pry::Helpers::BaseHelpers
    extend Pry::Helpers::CommandHelpers

    class << self
      def edit_tempfile_with_content(initial_content, line=1)
        temp_file do |f|
          f.puts(initial_content)
          f.flush
          f.close(false)
          invoke_editor(f.path, line, false)
          File.read(f.path)
        end
      end

      def invoke_editor(file, line, reloading)
        raise CommandError, "Please set Pry.config.editor or export $VISUAL or $EDITOR" unless Pry.config.editor
        if Pry.config.editor.respond_to?(:call)
          args = [file, line, reloading][0...(Pry.config.editor.arity)]
          editor_invocation = Pry.config.editor.call(*args)
        else
          editor_invocation = "#{Pry.config.editor} #{blocking_flag_for_editor(reloading)} #{start_line_syntax_for_editor(file, line)}"
        end
        return nil unless editor_invocation

        if jruby?
          begin
            require 'spoon'
            pid = Spoon.spawnp(*editor_invocation.split)
            Process.waitpid(pid)
          rescue FFI::NotFoundError
            system(editor_invocation)
          end
        else
          # Note we dont want to use Pry.config.system here as that
          # may be invoked non-interactively (i.e via Open4), whereas we want to
          # ensure the editor is always interactive
          system(editor_invocation) or raise CommandError, "`#{editor_invocation}` gave exit status: #{$?.exitstatus}"
        end
      end

      private

      # Some editors that run outside the terminal allow you to control whether or
      # not to block the process from which they were launched (in this case, Pry).
      # For those editors, return the flag that produces the desired behavior.
      def blocking_flag_for_editor(block)
        case editor_name
        when /^emacsclient/
          '--no-wait' unless block
        when /^[gm]vim/
          '--nofork' if block
        when /^jedit/
          '-wait' if block
        when /^mate/, /^subl/
          '-w' if block
        end
      end

      # Return the syntax for a given editor for starting the editor
      # and moving to a particular line within that file
      def start_line_syntax_for_editor(file_name, line_number)
        if windows?
          file_name = file_name.gsub(/\//, '\\')
        end

        # special case for 1st line
        return file_name if line_number <= 1

        case editor_name
        when /^[gm]?vi/, /^emacs/, /^nano/, /^pico/, /^gedit/, /^kate/
          "+#{line_number} #{file_name}"
        when /^mate/, /^geany/
          "-l #{line_number} #{file_name}"
        when /^subl/
          "#{file_name}:#{line_number}"
        when /^uedit32/
          "#{file_name}/#{line_number}"
        when /^jedit/
          "#{file_name} +line:#{line_number}"
        else
          if windows?
            "#{file_name}"
          else
            "+#{line_number} #{file_name}"
          end
        end
      end

      # Get the name of the binary that Pry.config.editor points to.
      #
      # This is useful for deciding which flags we pass to the editor as
      # we can just use the program's name and ignore any absolute paths.
      #
      # @example
      #   Pry.config.editor="/home/conrad/bin/textmate -w"
      #   editor_name
      #   # => textmate
      #
      def editor_name
        File.basename(Pry.config.editor).split(" ").first
      end

    end
  end
end
