require_relative 'basic_object'
class Pry::Config < Pry::BasicObject
  require_relative 'config/behavior'
  require_relative 'config/memoization'
  require_relative 'config/default'
  require_relative 'config/convenience'
  include Pry::Config::Behavior
  def self.shortcuts
    Convenience::SHORTCUTS
  end

  READLINE_WORD_ESCAPE_STR = " \t\n`><=;|&{("

  def input=(input)
    @lookup['input'] = input

    if input.respond_to?(:completer_word_break_characters=)
      begin
        input.completer_word_break_characters = READLINE_WORD_ESCAPE_STR
      rescue ArgumentError
        # Hi JRuby
        input.basic_word_break_characters = READLINE_WORD_ESCAPE_STR
      end
    end
  end
end
