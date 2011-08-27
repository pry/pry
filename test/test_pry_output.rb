
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

  describe "DEFAULT_PRINT" do
    it "should output the right thing" do
      mock_pry("{:a => 1}").should =~ /\{:a=>1\}/
    end

    it "should not be phased by un-inspectable things" do
      mock_pry("class NastyClass; undef pretty_inspect; end", "NastyClass.new").should =~ /#<NastyClass:0x[0-9a-f]+>/
    end

    it "should warn you about un-inspectable things" do
      mock_pry("class NastyClass; undef pretty_inspect; end", "NastyClass.new").should =~ /output error: #<(NoMethodError|NameError): undefined method `pretty_inspect'/
    end

    it "should warn you when you have badly behaved objects" do
      mock_pry("class UnCouth; def pretty_inspect(*a); :cussing_symbol; end; end", "UnCouth.new").should =~ /output error: .pretty_inspect didn't return a String/
    end
  end
end
