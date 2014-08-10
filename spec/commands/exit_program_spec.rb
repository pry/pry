require_relative '../helper'

describe "exit-program" do
  it 'should raise SystemExit' do
    expect { pry_eval('exit-program') }.to raise_error SystemExit
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
