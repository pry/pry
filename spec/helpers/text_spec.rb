# frozen_string_literal: true

describe Pry::Helpers::Text do
  describe ".colorize" do
    include Pry::Helpers::Text

    it "with color" do
      expect(
        colorize("Pry", :blue)
      ).to eq(
        "\e[0;34mPry\e[0m"
      )
    end

    it "with bold" do
      expect(
        colorize("Pry", bold: true)
      ).to eq(
        "\e[1mPry\e[0m"
      )
    end

    it "with color and bold" do
      expect(
        colorize("Pry", :blue, bold: true)
      ).to eq(
        "\e[1;34mPry\e[0m"
      )
    end

    it "with color, faded, and bold" do
      expect(
        colorize("Pry", :blue, bold: true, faded: true)
      ).to eq(
        "\e[1;2;34mPry\e[0m"
      )
    end

    it "unchanged" do
      expect(
        colorize("Pry", nil)
      ).to eq(
        "\e[0mPry\e[0m"
      )
    end
  end
end
