# frozen_string_literal: true

describe "exit-program" do
  it 'should raise SystemExit' do
    expect { pry_eval('exit-program') }.to raise_error SystemExit
  end

  it 'should exit the program with the provided value' do
    begin
      pry_eval 'exit-program 66'
    rescue SystemExit => e
      expect(e.status).to eq(66)
    else
      raise "Failed to raise SystemExit"
    end
  end
end
