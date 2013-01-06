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

    # The source for code_object prepared for display.
    def content_for(code_object)
      Code.new(code_object.source, start_line_for(code_object)).
        with_line_numbers(use_line_numbers?).to_s
    end
  end

  Pry::Commands.add_command(Pry::Command::ShowSource)
  Pry::Commands.alias_command 'show-method', 'show-source'
  Pry::Commands.alias_command '$', 'show-source'
end
