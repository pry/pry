require "bundler/setup"
require "bacon"
describe "Readline" do
  describe "on require of 'pry'" do
    it "is not made available" do
      require('pry').should.be.true
      defined?(Readline).should.be.nil
    end
  end

  describe "on invoke of 'pry'" do
    it "is made available" do
      Pry.start self, input: StringIO.new("exit-all\n"), output: StringIO.new
      defined?(Readline).should == "constant"
    end
  end
end
