require 'helper'

describe "show-input" do
  before do
    @t = pry_tester
  end

  it 'should correctly show the current lines in the input buffer' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
    STR

    @t.process_command 'show-input', eval_str
    @t.last_output.should =~ /\A\d+: def hello\n\d+:   puts :bing/
  end
end
