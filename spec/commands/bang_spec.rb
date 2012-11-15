require 'helper'

describe "!" do
  before do
    @t = pry_tester
  end

  it 'should correctly clear the input buffer ' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
    STR

    @t.process_command '!', eval_str
    @t.last_output.should =~ /Input buffer cleared!/

    eval_str.should == ''
  end
end
