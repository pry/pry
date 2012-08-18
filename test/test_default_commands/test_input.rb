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
      x = "\"hello\""
      redirect_pry_io(InputTester.new("play x", "exit-all"), @str_output) do
        Pry.start binding, :hooks => Pry::Hooks.new
      end

      @str_output.string.should =~ /"hello"/
    end

    it 'should play a string variable  (with no args) using --lines to select what to play' do
      b = binding
      b.eval('x = "\"hello\"\n\"goodbye\"\n\"love\""')
      redirect_pry_io(InputTester.new("play x --lines 1", "exit-all"), @str_output) do
        Pry.start b, :hooks => Pry::Hooks.new
      end

      @str_output.string.should =~ /hello/
      @str_output.string.should.not =~ /love/
      @str_output.string.should.not =~ /goodbye/
    end

    it 'should play documentation with the -d switch' do
      o = Object.new

      # @v = 10
      # @y = 20
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('play -d test_method', "exit-all")) do
        o.pry
      end

      o.instance_variable_get(:@v).should == 10
      o.instance_variable_get(:@y).should == 20
    end

    it 'should play documentation with the -d switch (restricted by --lines)' do
      o = Object.new

      # @x = 0
      # @v = 10
      # @y = 20
      # @z = 30
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('play -d test_method --lines 2..3', "exit-all")) do
        o.pry
      end

      o.instance_variable_get(:@x).should == nil
      o.instance_variable_get(:@z).should == nil
      o.instance_variable_get(:@v).should == 10
      o.instance_variable_get(:@y).should == 20
    end


    it 'should play a method with the -m switch (a single line)' do
      o = Object.new
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('play -m test_method --lines 2', "exit-all"), @str_output) do
        o.pry
      end

      @str_output.string.should =~ /:test_method_content/
    end

    it 'should APPEND to the input buffer when playing a line with play -m, not replace it' do
      o = Object.new
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('def another_test_method', 'play -m test_method --lines 2', 'show-input', 'exit-all'), @str_output) do
        o.pry
      end

      @str_output.string.should =~ /def another_test_method/
      @str_output.string.should =~ /:test_method_content/
    end

    it 'should play a method with the -m switch (multiple line)' do
      o = Object.new

      def o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      redirect_pry_io(InputTester.new('play -m test_method --lines 3..4', "exit-all"), @str_output) do
        o.pry
      end

      o.instance_variable_get(:@var0).should == nil
      o.instance_variable_get(:@var1).should == 20
      o.instance_variable_get(:@var2).should == 30
      o.instance_variable_get(:@var3).should == nil
      @str_output.string.should =~ /30/
      @str_output.string.should.not =~ /20/
    end
  end

  describe "hist" do
    before do
      Pry.history.clear
      @hist = Pry.history
    end

    it 'should display the correct history' do
      @hist.push "hello"
      @hist.push "world"
      redirect_pry_io(InputTester.new("hist", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      o = Object.new
      @hist.push "@x = 10"
      @hist.push "@y = 20"
      @hist.push "@z = 30"
      redirect_pry_io(InputTester.new("hist --replay -1", "exit-all")) do
        o.pry
      end
      o.instance_variable_get(:@x).should == nil
      o.instance_variable_get(:@y).should == nil
      o.instance_variable_get(:@z).should == 30
    end

    it 'should replay a range of history correctly (range of items)' do
      o = Object.new
      @hist.push "@x = 10"
      @hist.push "@y = 20"
      redirect_pry_io(InputTester.new("hist --replay 0..2", "exit-all")) do
        o.pry
      end
      o.instance_variable_get(:@x).should == 10
      o.instance_variable_get(:@y).should == 20
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

      redirect_pry_io(InputTester.new("hist --grep o", "exit-all"), @str_output) do
        pry
      end
      @str_output.string.should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/

      # test more than one word in a regex match (def blah)
      @str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep def blah", "exit-all"), @str_output) do
        pry
      end
      @str_output.string.should =~ /def blah 1/

      @str_output = StringIO.new
      # test more than one word with leading white space in a regex match (def boink)
      redirect_pry_io(InputTester.new("hist --grep      def boink", "exit-all"), @str_output) do
        pry
      end
      @str_output.string.should =~ /def boink 2/
    end

    it 'should return last N lines in history with --tail switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      redirect_pry_io(InputTester.new("hist --tail 3", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.count.should == 3
      @str_output.string.should =~ /x\n\d+:.*y\n\d+:.*z/
    end

    it 'should apply --tail after --grep' do
      @hist.push "print 1"
      @hist.push "print 2"
      @hist.push "puts  3"
      @hist.push "print 4"
      @hist.push "puts  5"

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --tail 2 --grep print", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.count.should == 2
      @str_output.string.should =~ /\d:.*?print 2\n\d:.*?print 4/
    end

    it 'should apply --head after --grep' do
      @hist.push "puts  1"
      @hist.push "print 2"
      @hist.push "puts  3"
      @hist.push "print 4"
      @hist.push "print 5"

      redirect_pry_io(InputTester.new("hist --head 2 --grep print", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.count.should == 2
      @str_output.string.should =~ /\d:.*?print 2\n\d:.*?print 4/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should return first N lines in history with --head switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      redirect_pry_io(InputTester.new("hist --head 4", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.count.should == 4
      @str_output.string.should =~ /a\n\d+:.*b\n\d+:.*c/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should show lines between lines A and B with the --show switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      redirect_pry_io(InputTester.new("hist --show 1..4", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.count.should == 4
      @str_output.string.should =~ /b\n\d+:.*c\n\d+:.*d/
    end

    it "should not contain duplicated lines" do
      redirect_pry_io(InputTester.new("3", "_ += 1", "_ += 1", "hist", "exit-all"), @str_output) do
        pry
      end

      @str_output.string.each_line.grep(/_ \+= 1/).count.should == 1
    end

    it "should not contain duplicated lines" do
      redirect_pry_io(InputTester.new(":place_holder", "2 + 2", "", "", "3 + 3", "hist", "exit-all"), @str_output) do
        pry
      end

      a = @str_output.string.each_line.to_a.index{|line| line.include?("2 + 2") }
      b = @str_output.string.each_line.to_a.index{|line| line.include?("3 + 3") }

      (a + 1).should == b
    end
  end
end
