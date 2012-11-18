require 'helper'

describe "exit-program" do
  it 'should raise SystemExit' do
    proc {
      pry_eval('exit-program')
    }.should.raise SystemExit
  end

  it 'should exit the program with the provided value' do
    begin
      pry_eval 'exit-program 66'
    rescue SystemExit => e
      e.status.should == 66
    else
      raise "Failed to raise SystemExit"
    end
  end
end
