class Pry
  module Helpers
    def self.tablify_to_screen_width(things)
      things = things.compact

      if TerminalInfo.screen_size.nil?
        return things.join(Pry.config.ls.separator)
      end

      screen_width = (TerminalInfo.screen_size || [25, 80])[1]
      tablify(things, screen_width)
    end

    def self.tablify(things, line_length)
      table = Table.new(things, :column_count => things.size)
      table.column_count -= 1 until 0 == table.column_count or
        table.fits_on_line?(line_length)
      table
    end

    class Table
      attr_reader :items, :column_count
      def initialize items, args = {}
        @column_count = args[:column_count]
        self.items = items
      end

      def to_s
        rows_to_s.join("\n")
      end

      def rows_to_s style = :color_on
        widths = columns.map{|e| _max_width(e)}
        @rows_without_colors.map do |r|
          padded = []
          r.each_with_index do |e,i|
            next unless e
            item = e.ljust(widths[i])
            item.sub! e, _recall_color_for(e) if :color_on == style
            padded << item
          end
          padded.join(Pry.config.ls.separator)
        end
      end

      def items= items
        @items = items
        _rebuild_colorless_cache
        _recolumn
        items
      end

      def column_count= n
        @column_count = n
        _recolumn
      end

      def fits_on_line? line_length
        _max_width(rows_to_s :no_color) <= line_length
      end

      def columns
        @rows_without_colors.transpose
      end

      def ==(other); items == other.to_a end
      def to_a; items.to_a end

      private
      def _max_width(things)
        things.compact.map(&:size).max || 0
      end

      def _rebuild_colorless_cache
        @colorless_cache = {}
        @plain_items = []
        items.map do |e|
          plain = Pry::Helpers::Text.strip_color(e)
          @colorless_cache[plain] = e
          @plain_items << plain
        end
      end

      def _recolumn
        @rows_without_colors = []
        return if items.size.zero?
        row_count = (items.size.to_f/column_count).ceil
        row_count.times do |i|
          row_indices = (0...column_count).map{|e| row_count*e+i}
          @rows_without_colors << row_indices.map{|e| @plain_items[e]}
        end
      end

      def _recall_color_for thing
        @colorless_cache[thing]
      end
    end

  end
end
