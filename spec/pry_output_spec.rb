require_relative 'helper'

describe Pry do
  describe "output failsafe" do
    after do
      Pry.config.print = Pry::DEFAULT_PRINT
    end

    it "should catch serialization exceptions" do
      Pry.config.print = lambda { |*a| raise "catch-22" }

      expect { mock_pry("1") }.to_not raise_error
    end

    it "should display serialization exceptions" do
      Pry.config.print = lambda { |*a| raise "catch-22" }

      expect(mock_pry("1")).to match(/\(pry\) output error: #<RuntimeError: catch-22>/)
    end

    it "should catch errors serializing exceptions" do
      Pry.config.print = lambda do |*a|
        ex = Exception.new("catch-22")
        class << ex
          def inspect; raise ex; end
        end
        raise ex
      end

      expect(mock_pry("1")).to match(/\(pry\) output error: failed to show result/)
    end
  end

  describe "DEFAULT_PRINT" do
    it "should output the right thing" do
      expect(mock_pry("[1]")).to match(/^=> \[1\]/)
    end

    it "should include the =>" do
      pry = Pry.new
      accumulator = StringIO.new
      pry.config.output = accumulator
      pry.config.print.call(accumulator, [1], pry)
      expect(accumulator.string).to eq("=> \[1\]\n")
    end

    it "should not be phased by un-inspectable things" do
      expect(mock_pry("class NastyClass; undef pretty_inspect; end", "NastyClass.new")).to match(/#<.*NastyClass:0x.*?>/)
    end

    it "doesn't leak colour for object literals" do
      expect(mock_pry("Object.new")).to match(/=> #<Object:0x[a-z0-9]+>\n/)
    end
  end

  describe "output_prefix" do
    it "should be able to change output_prefix" do
      pry = Pry.new
      accumulator = StringIO.new
      pry.config.output = accumulator
      pry.config.output_prefix = "-> "
      pry.config.print.call(accumulator, [1], pry)
      expect(accumulator.string).to eq("-> \[1\]\n")
    end
  end

  describe "color" do
    before do
      Pry.config.color = true
    end

    after do
      Pry.config.color = false
    end

    it "should colorize strings as though they were ruby" do
      pry = Pry.new
      accumulator = StringIO.new
      colorized   = CodeRay.scan("[1]", :ruby).term
      pry.config.output = accumulator
      pry.config.print.call(accumulator, [1], pry)
      expect(accumulator.string).to eq("=> #{colorized}\n")
    end

    it "should not colorize strings that already include color" do
      pry = Pry.new
      f = Object.new
      def f.inspect
        "\e[1;31mFoo\e[0m"
      end
      accumulator = StringIO.new
      pry.config.output = accumulator
      pry.config.print.call(accumulator, f, pry)
      # We add an extra \e[0m to prevent color leak
      expect(accumulator.string).to eq("=> \e[1;31mFoo\e[0m\e[0m\n")
    end
  end

  describe "output suppression" do
    before do
      @t = pry_tester
    end
    it "should normally output the result" do
      expect(mock_pry("1 + 2")).to eq("=> 3\n")
    end

    it "should not output anything if the input ends with a semicolon" do
      expect(mock_pry("1 + 2;")).to eq("")
    end

    it "should output something if the input ends with a comment" do
      expect(mock_pry("1 + 2 # basic addition")).to eq("=> 3\n")
    end

    it "should not output something if the input is only a comment" do
      expect(mock_pry("# basic addition")).to eq("")
    end
  end

  describe "custom non-IO object as $stdout" do
    it "does not crash pry" do
      old_stdout = $stdout
      pry_eval = pry_tester(binding)
      expect(pry_eval.eval("$stdout = Class.new { def write(*) end }.new", ":ok")).to eq(:ok)
      $stdout = old_stdout
    end
  end
end
