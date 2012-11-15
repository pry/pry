require 'helper'

describe "disable-pry" do
  before do
    @t = pry_tester
  end

  after do
    ENV.delete 'DISABLE_PRY'
  end

  it 'should quit the current session' do
    lambda{
      @t.process_command 'disable-pry'
    }.should.throw(:breakout)
  end

  it "should set DISABLE_PRY" do
    ENV['DISABLE_PRY'].should == nil
    lambda{
      @t.process_command 'disable-pry'
    }.should.throw(:breakout)
    ENV['DISABLE_PRY'].should == 'true'
  end
end
