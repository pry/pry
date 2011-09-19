require 'helper'

describe "Pry.config.exception_whitelist" do
  it 'should rescue all exceptions NOT specified on whitelist' do
    Pry.config.exception_whitelist.include?(NameError).should == false
    lambda { Pry.start(self, :input => StringIO.new("raise NameError\nexit"), :output => StringIO.new) }.should.not.raise NameError
  end

  it 'should NOT rescue exceptions specified on whitelist' do
    old_whitelist = Pry.config.exception_whitelist
    Pry.config.exception_whitelist = [NameError]
    lambda { Pry.start(self, :input => StringIO.new("raise NameError"), :output => StringIO.new) }.should.raise NameError
    Pry.config.exception_whitelist = old_whitelist
  end
end


