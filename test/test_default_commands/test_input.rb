require 'helper'

describe "Pry::DefaultCommands::Input" do
  before do
    @str_output = StringIO.new
    @t = pry_tester
  end

  describe "amend-line" do
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

  describe "show-input" do
    it 'should correctly show the current lines in the input buffer' do
      eval_str = unindent(<<-STR)
        def hello
          puts :bing
      STR

      @t.process_command 'show-input', eval_str
      @t.last_output.should =~ /\A\d+: def hello\n\d+:   puts :bing/
    end
  end

  describe "!" do
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

  describe "play" do
    it 'should play a string variable  (with no args)' do
      eval_str = ''

      @t.eval 'x = "\"hello\""'
      @t.process_command 'play x', eval_str

      eval_str.should == '"hello"'
    end

    it 'should play a string variable  (with no args) using --lines to select what to play' do
      eval_str = ''

      @t.eval 'x = "\"hello\"\n\"goodbye\"\n\"love\""'
      @t.process_command 'play x --lines 1', eval_str

      eval_str.should == "\"hello\"\n"
    end

    it 'should play documentation with the -d switch' do
      eval_str = ''
      o = Object.new

      # @v = 10
      # @y = 20
      def o.test_method
        :test_method_content
      end

      pry_tester(o).process_command 'play -d test_method', eval_str

      eval_str.should == unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should restrict -d switch with --lines' do
      eval_str = ''
      o = Object.new

      # @x = 0
      # @v = 10
      # @y = 20
      # @z = 30
      def o.test_method
        :test_method_content
      end

      pry_tester(o).process_command 'play -d test_method --lines 2..3', eval_str

      eval_str.should == unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should play a method with the -m switch (a single line)' do
      eval_str = ''
      o = Object.new

      def o.test_method
        :test_method_content
      end

      pry_tester(o).process_command 'play -m test_method --lines 2', eval_str

      eval_str.should == "  :test_method_content\n"
    end

    it 'should APPEND to the input buffer when playing a line with play -m, not replace it' do
      eval_str = unindent(<<-STR)
        def another_test_method
      STR

      o = Object.new
      def o.test_method
        :test_method_content
      end

      pry_tester(o).process_command 'play -m test_method --lines 2', eval_str

      eval_str.should == unindent(<<-STR)
        def another_test_method
          :test_method_content
      STR
    end

    it 'should play a method with the -m switch (multiple line)' do
      eval_str = ''
      o = Object.new

      def o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      pry_tester(o).process_command 'play -m test_method --lines 3..4', eval_str

      eval_str.should == unindent(<<-STR, 2)
        @var1 = 20
        @var2 = 30
      STR
    end
  end

  describe "hist" do
    before do
      Pry.history.clear
      @hist = Pry.history

      @t = pry_tester do
        # For looking at what hist pushes into the input stack. The
        # implementation of this helper will definitely have to change at some
        # point.
        def next_input
          @pry.input.string
        end
      end
    end

    it 'should display the correct history' do
      @hist.push "hello"
      @hist.push "world"

      @t.eval('hist').should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      o = Object.new
      @hist.push "@x = 10"
      @hist.push "@y = 20"
      @hist.push "@z = 30"

      @t.context = o
      @t.eval 'hist --replay -1'

      @t.next_input.should == "@z = 30\n"
    end

    it 'should replay a range of history correctly (range of items)' do
      o = Object.new
      @hist.push "@x = 10"
      @hist.push "@y = 20"

      @t.context = o
      @t.eval 'hist --replay 0..2'

      @t.next_input.should == "@x = 10\n@y = 20\n"
    end

    it 'should grep for correct lines in history' do
      @hist.push "abby"
      @hist.push "box"
      @hist.push "button"
      @hist.push "pepper"
      @hist.push "orange"
      @hist.push "grape"
      @hist.push "def blah 1"
      @hist.push "def boink 2"
      @hist.push "place holder"

      @t.eval('hist --grep o').should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/

      # test more than one word in a regex match (def blah)
      @t.eval('hist --grep def blah').should =~ /def blah 1/

      # test more than one word with leading white space in a regex match (def boink)
      @t.eval('hist --grep      def boink').should =~ /def boink 2/
    end

    it 'should return last N lines in history with --tail switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      out = @t.eval 'hist --tail 3'
      out.each_line.count.should == 3
      out.should =~ /x\n\d+:.*y\n\d+:.*z/
    end

    it 'should apply --tail after --grep' do
      @hist.push "print 1"
      @hist.push "print 2"
      @hist.push "puts  3"
      @hist.push "print 4"
      @hist.push "puts  5"

      out = @t.eval 'hist --tail 2 --grep print'
      out.each_line.count.should == 2
      out.should =~ /\d:.*?print 2\n\d:.*?print 4/
    end

    it 'should apply --head after --grep' do
      @hist.push "puts  1"
      @hist.push "print 2"
      @hist.push "puts  3"
      @hist.push "print 4"
      @hist.push "print 5"

      out = @t.eval 'hist --head 2 --grep print'
      out.each_line.count.should == 2
      out.should =~ /\d:.*?print 2\n\d:.*?print 4/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should return first N lines in history with --head switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      out = @t.eval 'hist --head 4'
      out.each_line.count.should == 4
      out.should =~ /a\n\d+:.*b\n\d+:.*c/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should show lines between lines A and B with the --show switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      out = @t.eval 'hist --show 1..4'
      out.each_line.count.should == 4
      out.should =~ /b\n\d+:.*c\n\d+:.*d/
    end

  end
end
