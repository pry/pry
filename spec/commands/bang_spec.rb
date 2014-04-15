require_relative '../helper'

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
    @t.last_output.should =~ /Input buffer cleared!/
    @t.eval_string.should == ''
  end

  it 'should not clear the input buffer for negation' do
    @t.push '! false'
    @t.last_output.should =~ /true/
    @t.eval_string.should == ''
  end
end
