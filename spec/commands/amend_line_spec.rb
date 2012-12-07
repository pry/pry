require 'helper'

describe "amend-line" do
  before do
    @t = pry_tester
  end

  it 'should amend the last line of input when no line number specified' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
    STR

    @t.process_command 'amend-line   puts :blah', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :blah
    STR
  end

  it 'should amend the specified line of input when line number given' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 1 def goodbye', eval_str

    eval_str.should == unindent(<<-STR)
      def goodbye
        puts :bing
        puts :bang
    STR
  end

  it 'should amend the first line of input when 0 given as line number' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 0 def goodbye', eval_str

    eval_str.should == unindent(<<-STR)
      def goodbye
        puts :bing
        puts :bang
    STR
  end

  it 'should amend a specified line when negative number given' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line -1   puts :bink', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bing
        puts :bink
    STR

    @t.process_command 'amend-line -2   puts :bink', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bink
        puts :bink
    STR
  end

  it 'should amend a range of lines of input when negative numbers given' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boat
    STR

    @t.process_command 'amend-line -3..-2   puts :bink', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bink
        puts :boat
    STR
  end

  it 'should correctly amend the specified line with interpolated text' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line   puts "#{goodbye}"', eval_str

    eval_str.should == unindent(<<-'STR')
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

    error.should.not.be.nil
    error.message.should =~ /No input to amend/
  end

  it 'should correctly amend the specified range of lines' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :heart
    STR

    @t.process_command 'amend-line 2..3   puts :bong', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bong
        puts :heart
    STR
  end

  it 'should correctly delete a specific line using the ! for content' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 3 !', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bing
        puts :boast
        puts :heart
    STR
  end

  it 'should correctly delete a range of lines using the ! for content' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 2..4 !', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :heart
    STR
  end

  it 'should correctly delete the previous line using the ! for content' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line !', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
    STR
  end

  it 'should amend the specified range of lines, with numbers < 0 in range' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
        puts :boast
        puts :heart
    STR

    @t.process_command 'amend-line 2..-2   puts :bong', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :bong
        puts :heart
    STR
  end

  it 'should correctly insert a line before a specified line using >' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 2 >  puts :inserted', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :inserted
        puts :bing
        puts :bang
    STR
  end

  it 'should ignore second value of range with > syntax' do
    eval_str = unindent(<<-STR)
      def hello
        puts :bing
        puts :bang
    STR

    @t.process_command 'amend-line 2..21 >  puts :inserted', eval_str

    eval_str.should == unindent(<<-STR)
      def hello
        puts :inserted
        puts :bing
        puts :bang
    STR
  end
end
