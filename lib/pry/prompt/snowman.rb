# coding: utf-8
module Pry::Prompt::Snowman
  extend self

  # https://unicode-table.com/en/1F48E/
  GEM_STONE = "💎"

  # Pry-like symbol.
  # https://unicode-table.com/en/26CF/
  PICK = "⛏"

  # https://unicode-table.com/en/2615/
  COFFEE = "☕"

  def prompt(obj, nest_level, pry, wait)
    h = pry.helpers
    e = wait ? "*" : ">"
    input_size = pry.input_array.size
    [
      h.bright_yellow(" #{input_size} "),
      " #{ruby_info(pry, h)} ",
      "#{PICK} (#{h.bold(Pry.view_clip(obj))})#{':%s' % nest_level if not nest_level.zero?}#{e}",
    ].compact.join
  end

  def ruby_info(pry, h)
    case
    when h.jruby?
      str = " #{COFFEE}  #{RUBY_ENGINE}-#{RUBY_VERSION} "
      h.bright_white_on_red(str)
    else
      str = " #{GEM_STONE}  #{RUBY_ENGINE}-#{RUBY_VERSION} "
      h.bright_white_on_red(str)
    end
  end
  private :ruby_info
end
