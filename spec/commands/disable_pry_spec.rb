require_relative '../helper'

describe "disable-pry" do
  before do
    @t = pry_tester
  end

  after do
    ENV.delete 'DISABLE_PRY'
  end

  it 'should quit the current session' do
    expect { @t.process_command 'disable-pry' }.to throw_symbol :breakout
  end

  it "should set DISABLE_PRY" do
    ENV['DISABLE_PRY'].should == nil
    expect { @t.process_command 'disable-pry' }.to throw_symbol :breakout
    ENV['DISABLE_PRY'].should == 'true'
  end
end
