require 'pry/commands/show_info'

class Pry
  class Command::ShowDoc < Command::ShowInfo
    include Pry::Helpers::DocumentationHelpers

    match 'show-doc'
    group 'Introspection'
    description 'Show the documentation for a method or class. Aliases: \?'

    banner <<-BANNER
      Usage: show-doc [OPTIONS] [METH]
      Aliases: ?

      Show the documentation for a method or class. Tries instance methods first and then methods by default.
      e.g show-doc hello_method    # docs for hello_method
      e.g show-doc Pry             # docs for Pry class
      e.g show-doc Pry -a          # docs for all definitions of Pry class (all monkey patches)
    BANNER

    def content_and_header_for_code_object(code_object)
      result = header(code_object)
      result << Code.new(render_doc_markup_for(code_object),
                         opts.present?(:b) ? 1 : start_line_for(code_object),
                         :text).
        with_line_numbers(use_line_numbers?).to_s
    end

    def content_and_headers_for_all_module_candidates(mod)
      result = "Found #{mod.number_of_candidates} candidates for `#{mod.name}` definition:\n"
      mod.number_of_candidates.times do |v|
        candidate = mod.candidate(v)
        begin
          result << "\nCandidate #{v+1}/#{mod.number_of_candidates}: #{candidate.source_file} @ line #{candidate.source_line}:\n"
          doc = Code.new(render_doc_markup_for(candidate),
                         opts.present?(:b) ? 1 : candidate.source_line,
                         :text).with_line_numbers(use_line_numbers?).to_s
          result << "Number of lines: #{doc.lines.count}\n\n" << doc
        rescue Pry::RescuableException
          result << "\nNo code found.\n"

          next
        end
      end
      result
    end

    # process the markup (if necessary) and apply colors
    def render_doc_markup_for(code_object)
      docs = docs_for(code_object)

      if code_object.command?
        # command '--help' shouldn't use markup highlighting
        docs
      else
        process_comment_markup(docs)
      end
    end

    # Return docs for the code_object, adjusting for whether the code_object
    # has yard docs available, in which case it returns those.
    # (note we only have to check yard docs for modules since they can
    # have multiple docs, but methods can only be doc'd once so we
    # dont need to check them)
    def docs_for(code_object)
      if code_object.module_with_yard_docs?
        # yard docs
        code_object.yard_doc
      else
        # normal docs (i.e comments above method/module/command)
        code_object.doc
      end
    end

    # takes into account possible yard docs, and returns yard_file / yard_line
    # Also adjusts for start line of comments (using start_line_for), which it has to infer
    # by subtracting number of lines of comment from start line of code_object
    def file_and_line_for(code_object)
      if code_object.module_with_yard_docs?
        [code_object.yard_file, code_object.yard_line]
      else
        [code_object.source_file, start_line_for(code_object)]
      end
    end

    # Generate a header (meta-data information) for all the code
    # object types: methods, modules, commands, procs...
    def header(code_object)
      file_name, line_num = file_and_line_for(code_object)
      h = "\n#{Pry::Helpers::Text.bold('From:')} #{file_name} "
      if code_object.c_method?
        h << "(C Method):"
      else
        h << "@ line #{line_num}:"
      end

      if code_object.real_method_object?
        h << "\n#{text.bold("Owner:")} #{code_object.owner || "N/A"}\n"
        h << "#{text.bold("Visibility:")} #{code_object.visibility}\n"
        h << "#{text.bold("Signature:")} #{code_object.signature}"
      end
      h << "\n#{Pry::Helpers::Text.bold('Number of lines:')} " <<
        "#{docs_for(code_object).lines.count}\n\n"
    end

    # figure out start line of docs by back-calculating based on
    # number of lines in the comment and the start line of the code_object
    # @return [Fixnum] start line of docs
    def start_line_for(code_object)
      if code_object.command?
         1
      else
        code_object.source_line.nil? ? 1 :
          (code_object.source_line - code_object.doc.lines.count)
      end
    end
  end

  Pry::Commands.add_command(Pry::Command::ShowDoc)
  Pry::Commands.alias_command '?', 'show-doc'
end
