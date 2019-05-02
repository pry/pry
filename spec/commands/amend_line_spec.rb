# frozen_string_literal: true

describe "amend-line" do
  before do
    @t = pry_tester
  end

  it 'should amend the last line of input when no line number specified' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
    STR

    @t.process_command 'amend-line   puts :blah'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :blah
    STR
  end

  it 'should amend the specified line of input when line number given' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 1 def goodbye'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def goodbye
        puts :bing
        puts :bang
    STR
  end

  it 'should amend the first line of input when 0 given as line number' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 0 def goodbye'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def goodbye
        puts :bing
        puts :bang
    STR
  end

  it 'should amend a specified line when negative number given' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line -1   puts :bink'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bing
        puts :bink
    STR

    @t.process_command 'amend-line -2   puts :bink'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bink
        puts :bink
    STR
  end

  it 'should amend a range of lines of input when negative numbers given' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :boat
    STR

    @t.process_command 'amend-line -3..-2   puts :bink'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bink
        puts :boat
    STR
  end

  it 'should correctly amend the specified line with interpolated text' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    # rubocop:disable Lint/InterpolationCheck
    @t.process_command 'amend-line   puts "#{goodbye}"'
    # rubocop:enable Lint/InterpolationCheck

    expect(@t.eval_string).to eq unindent(<<-'STR')
      def hello
        puts :bing
        puts "#{goodbye}"
    STR
  end

  it 'should display error if nothing to amend' do
    error = nil

    begin
      @t.process_command 'amend-line'
    rescue Pry::CommandError => e
      error = e
    end

    expect(error).not_to equal nil
    expect(error.message).to match(/No input to amend/)
  end

  it 'should correctly amend the specified range of lines' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :heart
    STR

    @t.process_command 'amend-line 2..3   puts :bong'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bong
        puts :heart
    STR
  end

  it 'should correctly delete a specific line using the ! for content' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 3 !'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bing
        puts :boast
        puts :heart
    STR
  end

  it 'should correctly delete a range of lines using the ! for content' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 2..4 !'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :heart
    STR
  end

  it 'should correctly delete the previous line using the ! for content' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line !'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
    STR
  end

  it 'should amend the specified range of lines, with numbers < 0 in range' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 2..-2   puts :bong'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :bong
        puts :heart
    STR
  end

  it 'should correctly insert a line before a specified line using >' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 2 >  puts :inserted'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :inserted
        puts :bing
        puts :bang
    STR
  end

  it 'should ignore second value of range with > syntax' do
    @t.push(*unindent(<<-STR).split("\n"))
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 2..21 >  puts :inserted'

    expect(@t.eval_string).to eq unindent(<<-STR)
      def hello
        puts :inserted
        puts :bing
        puts :bang
    STR
  end
end
