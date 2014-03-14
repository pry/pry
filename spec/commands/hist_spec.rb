require_relative '../helper'

describe "hist" do
  before do
    Pry.history.clear
    @hist = Pry.history

    @str_output = StringIO.new
    @t = pry_tester :history => @hist do
      # For looking at what hist pushes into the input stack. The implementation
      # of this helper will definitely have to change at some point.
      def next_input
        @pry.input.string
      end
    end
  end

  it 'should replay history correctly (single item)' do
    o = Object.new
    @hist.push "@x = 10"
    @hist.push "@y = 20"
    @hist.push "@z = 30"

    @t.push_binding o
    @t.eval 'hist --replay -1'

    o.instance_variable_get(:@z).should == 30
  end

  it 'should replay a range of history correctly (range of items)' do
    o = Object.new
    @hist.push "@x = 10"
    @hist.push "@y = 20"

    @t.push_binding o
    @t.eval 'hist --replay 0..2'
    @t.eval('[@x, @y]').should == [10, 20]
  end

  # this is to prevent a regression where input redirection is
  # replaced by just appending to `eval_string`
  it 'should replay a range of history correctly (range of commands)' do
    o = Object.new
    @hist.push "cd 1"
    @hist.push "cd 2"

    @t.eval("hist --replay 0..2")
    stack = @t.eval("Pad.stack = _pry_.binding_stack.dup")
    stack.map{ |b| b.eval("self") }.should == [TOPLEVEL_BINDING.eval("self"), 1, 2]
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

  it "should start from beginning if tail number is longer than history" do
    @hist.push 'Hyacinth'
    out = @t.eval 'hist --tail'
    out.should =~ /Hyacinth/
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
    @t.eval ":banzai"
    @t.eval "hist --replay 1"
    @t.eval("hist").should =~ /hist --replay 1/
  end

  it "should not contain lines produced by `--replay` flag" do
    @t.eval ":banzai"
    @t.eval ":geronimo"
    @t.eval ":huzzah"
    @t.eval("hist --replay 1..3")

    output = @t.eval("hist")
    output.should == "1: :banzai\n2: :geronimo\n3: :huzzah\n4: hist --replay 1..3\n"
  end

  it "should raise CommandError when index of `--replay` points out to another `hist --replay`" do
    @t.eval ":banzai"
    @t.eval "hist --replay 1"
    lambda do
      @t.eval "hist --replay 2"
    end.should.raise(Pry::CommandError, /Replay index 4 points out to another replay call: `hist --replay 1`/)
  end

  it "should disallow execution of `--replay <i>` when CommandError raised" do
    @t.eval "a = 0"
    @t.eval "a += 1"
    @t.eval "hist --replay 2"
    lambda{
      @t.eval "hist --replay 3"
    }.should.raise(Pry::CommandError)
    @t.eval("a").should == 2
    @t.eval("hist").lines.to_a.size.should == 5
  end

  it "excludes Pry commands from the history with `-e` switch" do
    @hist.push('a = 20')
    @hist.push('ls')
    pry_eval('hist -e').should == "1: a = 20\n"
  end

  describe "sessions" do
    before do
      @old_file = Pry.config.history.file
      Pry.config.history.file = File.expand_path('spec/fixtures/pry_history')
      @hist.load
    end

    after do
      Pry.config.history.file = @old_file
    end

    it "displays history only for current session" do
      @hist.push('hello')
      @hist.push('world')

      @t.eval('hist').should =~ /1:\shello\n2:\sworld/
    end

    it "displays all history (including the current sesion) with `--all` switch" do
      @hist.push('goodbye')
      @hist.push('world')

      output = @t.eval('hist --all')
      output.should =~ /1:\s:athos\n2:\s:porthos\n3:\s:aramis\n/
      output.should =~ /4:\sgoodbye\n5:\sworld/
    end
  end
end
