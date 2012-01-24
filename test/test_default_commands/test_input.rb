require 'helper'

describe "Pry::DefaultCommands::Input" do

  describe "amend-line" do
    it 'should correctly amend the last line of input when no line number specified ' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "amend-line puts :blah", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :blah/
    end

    it 'should correctly amend the specified line of input when line number given ' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line 1 def goodbye", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def goodbye\n\d+: puts :bing\n\d+: puts :bang/
    end

    it 'should correctly amend the specified line of input when line number given, 0 should behave as 1 ' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line 0 def goodbye", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def goodbye\n\d+: puts :bing\n\d+: puts :bang/
    end

    it 'should correctly amend the specified line of input when line number given (negative number)' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line -1 puts :bink", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bing\n\d+: puts :bink/

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line -2 puts :bink", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bink\n\d+: puts :bang/
    end

    it 'should correctly amend the specified range of lines of input when range of negative numbers given (negative number)' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boat", "amend-line -3..-2 puts :bink", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bink\n\d+: puts :boat/
    end

    it 'should correctly amend the specified line with string interpolated text' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", 'amend-line puts "#{goodbye}"', "show-input", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bing\n\d+: puts \"\#\{goodbye\}\"/
    end

    it 'should display error if nothing to amend' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("amend-line", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /No input to amend/
    end


    it 'should correctly amend the specified range of lines' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :heart", "amend-line 2..3 puts :bong", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bong\n\d+: puts :heart/
    end

    it 'should correctly delete a specific line using the ! for content' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boast", "puts :heart", "amend-line 3 !", "show-input", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def hello\n\d+: puts :bing\n\d+: puts :boast\n\d+: puts :heart/
    end

    it 'should correctly delete a range of lines using the ! for content' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boast", "puts :heart", "amend-line 2..4 !", "show-input", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def hello\n\d+: puts :heart\n\Z/
    end

    it 'should correctly delete the previous line using the ! for content' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boast", "puts :heart", "amend-line !", "show-input", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d+: def hello\n\d+: puts :bing\n\d+: puts :bang\n\d+: puts :boast\n\Z/
    end

    it 'should correctly amend the specified range of lines, using negative numbers in range' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boast", "puts :heart", "amend-line 2..-2 puts :bong", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\d+: def hello\n\d+: puts :bong\n\d+: puts :heart/
    end

    it 'should correctly insert a new line of input before a specified line using the > syntax' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line 2 >puts :inserted", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\d+: def hello\n\d+: puts :inserted\n\d+: puts :bing\n\d+: puts :bang/
    end

    it 'should correctly insert a new line of input before a specified line using the > syntax (should ignore second value of range)' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line 2..21 >puts :inserted", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\d+: def hello\n\d+: puts :inserted\n\d+: puts :bing\n\d+: puts :bang/
    end
  end

  describe "show-input" do
    it 'should correctly show the current lines in the input buffer' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bing/
    end
  end

  describe "!" do
    it 'should correctly clear the input buffer ' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "!", "show-input", "exit-all"), str_output) do
        pry
      end
      stripped_output = str_output.string.strip!
      stripped_output.each_line.count.should == 1
      stripped_output.should =~ /Input buffer cleared!/
    end
  end

  describe "play" do
    it 'should play a string variable  (with no args)' do
      b = binding
      b.eval('x = "\"hello\""')
      redirect_pry_io(InputTester.new("play x", "exit-all"), str_output = StringIO.new) do
        Pry.start b, :hooks => Pry::Hooks.new
      end
      str_output.string.should =~ /hello/
    end

    it 'should play a string variable  (with no args) using --lines to select what to play' do
      b = binding
      b.eval('x = "\"hello\"\n\"goodbye\"\n\"love\""')
      redirect_pry_io(InputTester.new("play x --lines 1", "exit-all"), str_output = StringIO.new) do
        Pry.start b, :hooks => Pry::Hooks.new
      end
      str_output.string.should =~ /hello/
      str_output.string.should.not =~ /love/
      str_output.string.should.not =~ /goodbye/
    end

    it 'should play documentation with the -d switch' do
      o = Object.new

      # @v = 10
      # @y = 20
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('play -d test_method', "exit-all"), str_output = StringIO.new) do
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

      redirect_pry_io(InputTester.new('play -d test_method --lines 2..3', "exit-all"), str_output = StringIO.new) do
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

      redirect_pry_io(InputTester.new('play -m test_method --lines 2', "exit-all"), str_output = StringIO.new) do
        o.pry
      end

      str_output.string.should =~ /:test_method_content/
    end

    it 'should APPEND to the input buffer when playing a line with play -m, not replace it' do
      o = Object.new
      def o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('def another_test_method', 'play -m test_method --lines 2', 'show-input', 'exit-all'), str_output = StringIO.new) do
        o.pry
      end
      str_output.string.should =~ /def another_test_method/
      str_output.string.should =~ /:test_method_content/
    end


    it 'should play a method with the -m switch (multiple line)' do
      o = Object.new

      def o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      redirect_pry_io(InputTester.new('play -m test_method --lines 3..4', "exit-all"), str_output = StringIO.new) do
        o.pry
      end

      o.instance_variable_get(:@var0).should == nil
      o.instance_variable_get(:@var1).should == 20
      o.instance_variable_get(:@var2).should == 30
      o.instance_variable_get(:@var3).should == nil
      str_output.string.should =~ /30/
      str_output.string.should.not =~ /20/
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
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      o = Object.new
      @hist.push "@x = 10"
      @hist.push "@y = 20"
      @hist.push "@z = 30"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay -1", "exit-all"), str_output) do
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
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0..2", "exit-all"), str_output) do
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

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep o", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/

      # test more than one word in a regex match (def blah)
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep def blah", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /def blah 1/

      # test more than one word with leading white space in a regex match (def boink)
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep      def boink", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /def boink 2/
    end

    it 'should return last N lines in history with --tail switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --tail 3", "exit-all"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 3
      str_output.string.should =~ /x\n\d+:.*y\n\d+:.*z/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should return first N lines in history with --head switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --head 4", "exit-all"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /a\n\d+:.*b\n\d+:.*c/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should show lines between lines A and B with the --show switch' do
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --show 1..4", "exit-all"), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /b\n\d+:.*c\n\d+:.*d/
    end

    it "should not contain duplicated lines" do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("3", "_ += 1", "_ += 1", "hist", "exit-all"), str_output) do
        pry
      end

      str_output.string.each_line.grep(/_ \+= 1/).count.should == 1
    end

    it "should not contain duplicated lines" do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new(":place_holder", "2 + 2", "", "", "3 + 3", "hist", "exit-all"), str_output) do
        pry
      end

      a = str_output.string.each_line.to_a.index{|line| line.include?("2 + 2") }
      b = str_output.string.each_line.to_a.index{|line| line.include?("3 + 3") }

      (a + 1).should == b
    end
  end


end
