require 'pry/commands/show_info'

class Pry
  class Command::ShowSource < Command::ShowInfo
    match 'show-source'
    group 'Introspection'
    description 'Show the source for a method or class. Aliases: $, show-method'

    banner <<-BANNER
      Usage: show-source [OPTIONS] [METH|CLASS]
      Aliases: $, show-method

      Show the source for a method or class. Tries instance methods first and then methods by default.

      e.g: `show-source hello_method`
      e.g: `show-source hello_method`
      e.g: `show-source Pry#rep`         # source for Pry#rep method
      e.g: `show-source Pry`             # source for Pry class
      e.g: `show-source Pry -a`          # source for all Pry class definitions (all monkey patches)
      e.g: `show-source Pry --super      # source for superclass of Pry (Object class)

      https://github.com/pry/pry/wiki/Source-browsing#wiki-Show_method
    BANNER

    def content_and_header_for_code_object(code_object)
      result = header(code_object)
      result << Code.new(code_object.source, start_line_for(code_object)).
        with_line_numbers(use_line_numbers?).to_s
    end

    def content_and_headers_for_all_module_candidates(mod)
      result = "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
      mod.number_of_candidates.times do |v|
        candidate = mod.candidate(v)
        begin
          result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.file} @ line #{candidate.line}:\n"
          code = Code.from_module(mod, start_line_for(candidate), v).with_line_numbers(use_line_numbers?).to_s
          result << "Number of lines: #{code.lines.count}\n\n" << code
        rescue Pry::RescuableException
          result << "\nNo code found.\n"
          next
        end
      end
      result
    end

    # Generate a header (meta-data information) for all the code
    # object types: methods, modules, commands, procs...
    def header(code_object)
      file_name, line_num = code_object.source_file, code_object.source_line
      h = "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} "
      if code_object.c_method?
        h << "(C Method):"
      else
        h << "@ line #{line_num}:"
      end

      if code_object.real_method_object?
        h << "\n#{text.bold("Owner:")} #{code_object.owner || "N/A"}\n"
        h << "#{text.bold("Visibility:")} #{code_object.visibility}"
      end
      h << "\n#{Pry::Helpers::Text.bold('Number of lines:')} " <<
        "#{code_object.source.lines.count}\n\n"
    end
  end

  Pry::Commands.add_command(Pry::Command::ShowSource)
  Pry::Commands.alias_command 'show-method', 'show-source'
  Pry::Commands.alias_command '$', 'show-source'
end
