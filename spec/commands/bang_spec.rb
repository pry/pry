# frozen_string_literal: true

describe "!" do
  before do
    @t = pry_tester
  end

  it 'should correctly clear the input buffer ' do
    @t.push unindent(<<-STR)
      def hello
        puts :bing
    STR

    @t.process_command '!'
    expect(@t.last_output).to match(/Input buffer cleared!/)
    expect(@t.eval_string).to eq('')
  end

  it 'should not clear the input buffer for negation' do
    @t.push '! false'
    expect(@t.last_output).to match(/true/)
    expect(@t.eval_string).to eq('')
  end
end
