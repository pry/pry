require 'helper'

describe "disable-pry" do
  before do
    @t = pry_tester
  end

  after do
    ENV.delete 'NO_PRY'
  end

  it 'should quit the current session' do
    lambda{
      @t.process_command 'disable-pry'
    }.should.throw(:breakout)
  end

  it "should set NO_PRY" do
    ENV['NO_PRY'].should == nil
    lambda{
      @t.process_command 'disable-pry'
    }.should.throw(:breakout)
    ENV['NO_PRY'].should == 'true'
  end
end
