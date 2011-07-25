require 'helper'

describe "Pry::DefaultCommands::Input" do

  describe "amend-line-N" do
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

      str_output.string.should =~ /\A\d+: def hello\n\d+: puts :bing\n\d+: puts \"\#{goodbye}\"/
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
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "puts :boast", "puts :heart", "amend-line-2..-2 puts :bong", "show-input", "exit-all"), str_output) do
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
    it 'should play a string of code (with no args)' do
      redirect_pry_io(InputTester.new("play :test_string", "exit-all"), str_output = StringIO.new) do
        pry
      end
      str_output.string.should =~ /:test_string/
    end

    it 'should play an interpolated string of code (with no args)' do
      $obj = ":test_string_interpolated"
      redirect_pry_io(InputTester.new('play #{$obj}', "exit-all"), str_output = StringIO.new) do
        pry
      end
      str_output.string.should =~ /:test_string_interpolated/
    end

    it 'should play a method with the -m switch (a single line)' do
      $o = Object.new
      def $o.test_method
        :test_method_content
      end

      redirect_pry_io(InputTester.new('play -m $o.test_method --lines 2', "exit-all"), str_output = StringIO.new) do
        pry
      end

      str_output.string.should =~ /:test_method_content/
      $o = nil
    end

    it 'should play a method with the -m switch (multiple line)' do
      $o = Object.new
      def $o.test_method
        1 + 102
        5 * 6
      end

      redirect_pry_io(InputTester.new('play -m $o.test_method --lines 2..3', "exit-all"), str_output = StringIO.new) do
        pry
      end

      str_output.string.should =~ /103\n.*30/
      $o = nil
    end

  end

  describe "hist" do
    push_first_hist_line = lambda do |hist, line|
      hist.push line
    end

    before do
      Readline::HISTORY.shift until Readline::HISTORY.empty?
      @hist = Readline::HISTORY
    end

    it 'should display the correct history' do
      push_first_hist_line.call(@hist, "'bug in 1.8 means this line is ignored'")
      @hist.push "hello"
      @hist.push "world"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      push_first_hist_line.call(@hist, ":hello")
      @hist.push ":blah"
      @hist.push ":bucket"
      @hist.push ":ostrich"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay -1", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /ostrich/
    end

    it 'should replay a range of history correctly (range of items)' do
      push_first_hist_line.call(@hist, "'bug in 1.8 means this line is ignored'")
      @hist.push ":hello"
      @hist.push ":carl"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0..2", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /:hello\n.*:carl/
    end

    it 'should grep for correct lines in history' do
      push_first_hist_line.call(@hist, "apple")
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
      redirect_pry_io(InputTester.new("hist --grep o", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/

      # test more than one word in a regex match (def blah)
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep def blah", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /def blah 1/

      # test more than one word with leading white space in a regex match (def boink)
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep      def boink", "exit-all", :history => @hist), str_output) do
        pry
      end
      str_output.string.should =~ /def boink 2/
    end

    it 'should return last N lines in history with --tail switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --tail 3", "exit-all", :history => @hist), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 3
      str_output.string.should =~ /x\n\d+:.*y\n\d+:.*z/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should return first N lines in history with --head switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --head 4", "exit-all", :history => @hist), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /a\n\d+:.*b\n\d+:.*c/
    end

    # strangeness in this test is due to bug in Readline::HISTORY not
    # always registering first line of input
    it 'should show lines between lines A and B with the --show switch' do
      push_first_hist_line.call(@hist, "0")
      ("a".."z").each do |v|
        @hist.push v
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --show 1..4", "exit-all", :history => @hist), str_output) do
        pry
      end

      str_output.string.each_line.count.should == 4
      str_output.string.should =~ /b\n\d+:.*c\n\d+:.*d/
    end
  end


end
