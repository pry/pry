# frozen_string_literal: true

describe Pry::Helpers::Text do
  describe "#strip_color" do
    [
      ["\e[1A\e[0G[2] pry(main)> puts \e[31m\e[1;31m'\e[0m\e[31m"\
         "hello\e[1;31m'\e[0m\e[31m\e[0m\e[1B\e[0G",
       "\e[1A\e[0G[2] pry(main)> puts 'hello'\e[1B\e[0G"],
      ["\e[31m\e[1;31m'\e[0m\e[31mhello\e[1;31m'\e[0m\e[31m\e[0m\e[1B\e[0G",
       "'hello'\e[1B\e[0G"],
      %w[string string]
    ].each do |(text, text_without_color)|
      it "removes color code from text #{text.inspect}" do
        expect(subject.strip_color(text)).to eql(text_without_color)
      end
    end
  end
end
