# frozen_string_literal: true

describe "pry_backtrace" do
  before do
    @t = pry_tester
  end

  it 'should print a backtrace' do
    @t.process_command 'pry-backtrace'
    expect(@t.last_output).to start_with('Backtrace:')
  end
end
