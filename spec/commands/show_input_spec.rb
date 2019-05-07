# frozen_string_literal: true

describe "show-input" do
  before do
    @t = pry_tester
  end

  it 'should correctly show the current lines in the input buffer' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
    STR

    @t.process_command 'show-input'
    expect(@t.last_output).to match(/\A\d+: def hello\n\d+:   puts :bing/)
  end
end
