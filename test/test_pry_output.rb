
describe Pry do
  describe "output failsafe" do
    after do
      Pry.config.print = Pry::DEFAULT_PRINT
    end

    it "should catch serialization exceptions" do
      Pry.config.print = lambda { |*a| raise "catch-22" }

      lambda {
        mock_pry("1")
      }.should.not.raise
    end

    it "should display serialization exceptions" do
      Pry.config.print = lambda { |*a| raise "catch-22" }

      mock_pry("1").should =~ /output error: #<RuntimeError: catch-22>/
    end

    it "should catch errors serializing exceptions" do
      Pry.config.print = lambda do |*a|
        raise Exception.new("catch-22").tap{ |e| class << e; def inspect; raise e; end; end }
      end

      mock_pry("1").should =~ /output error: failed to show result/
    end
  end
end
