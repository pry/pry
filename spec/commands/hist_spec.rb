require 'helper'

describe "hist" do
  before do
    Pry.history.clear
    @hist = Pry.history

    @str_output = StringIO.new
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

  # this is to prevent a regression where input redirection is
  # replaced by just appending to `eval_string`
  it 'should replay a range of history correctly (range of commands)' do
    o = Object.new
    @hist.push "cd 1"
    @hist.push "cd 2"
    redirect_pry_io(InputTester.new("hist --replay 0..2", "Pad.stack = _pry_.binding_stack.dup", "exit-all")) do
      o.pry
    end
    o = Pad.stack[-2..-1].map { |v| v.eval('self') }
    o.should == [1, 2]
    Pad.clear
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

  it "should store a call with `--replay` flag" do
    redirect_pry_io(InputTester.new(":banzai", "hist --replay 1",
                                    "hist", "exit-all"), @str_output) do
      Pry.start
    end

    @str_output.string.should =~ /hist --replay 1/
  end

  it "should not contain lines produced by `--replay` flag" do
    redirect_pry_io(InputTester.new(":banzai", ":geronimo", ":huzzah",
                                    "hist --replay 1..3", "hist",
                                    "exit-all"), @str_output) do
      Pry.start
    end

    @str_output.string.each_line.to_a.reject { |line| line.start_with?("=>") }.size.should == 4
    @str_output.string.each_line.to_a.last.should =~ /hist --replay 1\.\.3/
    @str_output.string.each_line.to_a[-2].should =~ /:huzzah/
  end

  it "should raise CommandError when index of `--replay` points out to another `hist --replay`" do
    redirect_pry_io(InputTester.new(":banzai", "hist --replay 1",
                                    "hist --replay 2", "exit-all"), @str_output) do
      Pry.start
    end

    @str_output.string.should =~ /Replay index 2 points out to another replay call: `hist --replay 1`/
  end

  it "should disallow execution of `--replay <i>` when CommandError raised" do
    redirect_pry_io(InputTester.new("a = 0", "a += 1", "hist --replay 2",
                                    "hist --replay 3", "'a is ' + a.to_s",
                                    "hist", "exit-all"), @str_output) do
      Pry.start
    end

    @str_output.string.each_line.to_a.reject { |line| line !~ /\A\d/ }.size.should == 5
    @str_output.string.should =~ /a is 2/
  end
end
