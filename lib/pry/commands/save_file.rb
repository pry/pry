require 'pry/commands/code_collector'

class Pry
  class Command::SaveFile < Pry::ClassCommand
    include Command::CodeCollector

    match 'save-file'
    group 'Input and Output'
    description 'Export to a file using content from the REPL.'

    banner <<-USAGE
      Usage: save-file [OPTIONS] [FILE]
      Save REPL content to a file.
      e.g: save-file my_method ./hello.rb
      e.g: save-file -i 1..10 ./hello.rb --append
      e.g: save-file show-method ./my_command.rb
      e.g: save-file sample_file.rb --lines 2..10 ./output_file.rb
    USAGE

    def options(opt)
      super
      opt.on :to=, "Select where content is to be saved."
      opt.on :a, :append, "Append output to file."
    end

    def process
      check_for_errors

      if file_name.empty?
        display_content
      else
        save_file
      end
    end

    def file_name
      opts[:to] || ""
    end

    def check_for_errors
      raise CommandError, "Found no code to save." if content.empty?
    end

    def save_file
      File.open(file_name, mode) do |f|
        f.puts content
      end
      output.puts "#{file_name} successfully saved"
    end

    def display_content
      output.puts content
      output.puts "\n\n--\nPlease use `--to FILE` to export to a file."
      output.puts "No file saved!\n--"
    end

    def mode
      opts.present?(:append) ? "a" : "w"
    end
  end

  Pry::Commands.add_command(Pry::Command::SaveFile)
end
