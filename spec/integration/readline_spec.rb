require "bundler/setup"
require "bacon"

describe "Readline" do
  describe "on require of 'pry'" do
    it "is not made available" do
      require('pry').should.be.true
      defined?(Readline).should.be.nil
    end
  end
end
