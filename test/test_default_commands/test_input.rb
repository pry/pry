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
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", "amend-line-0 def goodbye", "show-input", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /\A\d+: def goodbye\n\d+: puts :bing\n\d+: puts :bang/
    end

    it 'should correctly amend the specified line with string interpolated text' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("def hello", "puts :bing", "puts :bang", 'amend-line puts "#{goodbye}"', "show-input", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\A\d+: def goodbye\n\d+: puts :bing\n\d+: puts \"\#{goodbye}\"/
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
      redirect_pry_io(InputTester.new("hist", "exit-all"), str_output) do
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
      redirect_pry_io(InputTester.new("hist --replay -1", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /ostrich/
    end

    it 'should replay a range of history correctly (range of items)' do
      push_first_hist_line.call(@hist, "'bug in 1.8 means this line is ignored'")
      @hist.push ":hello"
      @hist.push ":carl"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0..2", "exit-all"), str_output) do
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

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --grep o", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /\d:.*?box\n\d:.*?button\n\d:.*?orange/
    end

    it 'should return last N lines in history with --tail switch' do
      push_first_hist_line.call(@hist, "0")
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
      push_first_hist_line.call(@hist, "0")
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
      push_first_hist_line.call(@hist, "0")
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
  end


end
