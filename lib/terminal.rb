require 'rexml/parsers/baseparser'

module Kramdown

  module Converter

    # Converts a Kramdown::Document to Terminal
    class Terminal < Html

      def convert_blank(el, indent)
        " "
      end

      def convert_text(el, indent)
        el.value
      end

      def convert_p(el, indent)
        el.options[:transparent] ?  "#{inner(el, indent)}\n" : "\n#{inner(el, indent)}\n"
      end

      def convert_codeblock(el, indent)
        code_map = el.value.chomp!.split("\n").map{ |item| "    " << item }
        code_map = code_map.map{ |item| CodeRay.scan(item, 'ruby').term } if Pry.color
        "\n#{code_map.join("\n")}\n"
      end

      def convert_blockquote(el, indent)
        "\"{inner(el, indent)}\"\n"
      end

      def convert_header(el, indent)
        content = inner(el,0).strip
        level = el.options[:level]
        color  = (level < 3) ? 1 : 30 + level
        Pry.color ? "\n\e[#{color}m#{content}\e[0m\n\e[#{color}m\e[0m" : "\n#{content}\n"
      end

      def convert_hr(el, indent)
        "-"*60 << "\n"
      end

      def convert_ul(el, indent)
        "\n  #{inner(el, indent)}"
      end

      def convert_li(el, indent)
        output = "* " 
        res = inner(el, indent)
        if el.children.empty? || (el.children.first.type == :p && el.children.first.options[:transparent])
          output << res << (res =~ /\n\Z/ ? ' '*indent : '')
        else
          output << "\n" << res << ' '*indent
        end
      end

      def convert_xml_comment(el, indent)
      end

      def convert_comment(el, indent)
      end

      def convert_br(el, indent)
        "\n"
      end

      def convert_a(el, indent)
        res = inner(el, indent)
        attr = el.attr.dup
        res = obfuscate(res) if attr['href'] =~ /^mailto:/
        "(#{res})"
      end

      def convert_img(el, indent)
      end

      def convert_codespan(el, indent)
        result = el.value
        result = CodeRay.scan(result, 'ruby').term  if Pry.color
        result
      end

    end
  end
end
