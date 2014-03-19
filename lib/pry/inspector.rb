class Pry::Inspector
  MAP = {
    "default" => {
      value: Pry::DEFAULT_PRINT,
      description: <<-DESCRIPTION.each_line.map(&:lstrip!)
        the default pry inspector. it has paging and color support, and uses pretty_inspect
        when printing an object.
      DESCRIPTION
    },

    "simple" => {
      value: Pry::SIMPLE_PRINT,
      description: <<-DESCRIPTION.each_line.map(&:lstrip)
        a simple inspector that uses #puts and #inspect when printing an object.
        it has no pager, color, or pretty_inspect support.
      DESCRIPTION
    },

    "clipped" => {
      value: Pry::CLIPPED_PRINT,
      description: <<-DESCRIPTION.each_line.map(&:lstrip)
        the clipped inspector has the same features as the 'simple' inspector but prints
        large objects as a smaller string.
      DESCRIPTION
    }
  }
end
