require 'helper'

describe "Pry.config.exception_whitelist" do
  before do
    @str_output = StringIO.new
  end

  it 'should rescue all exceptions NOT specified on whitelist' do
    Pry.config.exception_whitelist.include?(NameError).should == false
    lambda { Pry.start(self, :input => StringIO.new("raise NameError\nexit"), :output => @str_output) }.should.not.raise NameError
  end

  it 'should NOT rescue exceptions specified on whitelist' do
    old_whitelist = Pry.config.exception_whitelist
    Pry.config.exception_whitelist = [NameError]
    lambda { Pry.start(self, :input => StringIO.new("raise NameError"), :output => @str_output) }.should.raise NameError
    Pry.config.exception_whitelist = old_whitelist
  end
end


