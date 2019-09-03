# frozen_string_literal: true

describe "hist" do
  before do
    Pry.history.clear
    @hist = Pry.history

    @str_output = StringIO.new
    @t = pry_tester history: @hist do
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

    expect(o.instance_variable_get(:@z)).to eq 30
  end

  it 'should replay a range of history correctly (range of items)' do
    o = Object.new
    @hist.push "@x = 10"
    @hist.push "@y = 20"

    @t.push_binding o
    @t.eval 'hist --replay 0..2'
    expect(@t.eval('[@x, @y]')).to eq [10, 20]
  end

  # this is to prevent a regression where input redirection is
  # replaced by just appending to `eval_string`
  it 'should replay a range of history correctly (range of commands)' do
    @hist.push "cd 1"
    @hist.push "cd 2"

    @t.eval("hist --replay 0..2")
    stack = @t.eval("Pad.stack = pry_instance.binding_stack.dup")
    expect(stack.map { |b| b.eval("self") }).to eq [TOPLEVEL_BINDING.eval("self"), 1, 2]
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

    expect(@t.eval('hist --grep o')).to match(/\d:.*?box\n\d:.*?button\n\d:.*?orange/)

    # test more than one word in a regex match (def blah)
    expect(@t.eval('hist --grep def blah')).to match(/def blah 1/)

    # test more than one word with leading white space in a regex match (def boink)
    expect(@t.eval('hist --grep      def boink')).to match(/def boink 2/)
  end

  it 'should return last N lines in history with --tail switch' do
    ("a".."z").each do |v|
      @hist.push v
    end

    out = @t.eval 'hist --tail 3'
    expect(out.each_line.count).to eq 3
    expect(out).to match(/x\n\d+:.*y\n\d+:.*z/)
  end

  it "should start from beginning if tail number is longer than history" do
    @hist.push 'Hyacinth'
    out = @t.eval 'hist --tail'
    expect(out).to match(/Hyacinth/)
  end

  it 'should apply --tail after --grep' do
    @hist.push "print 1"
    @hist.push "print 2"
    @hist.push "puts  3"
    @hist.push "print 4"
    @hist.push "puts  5"

    out = @t.eval 'hist --tail 2 --grep print'
    expect(out.each_line.count).to eq 2
    expect(out).to match(/\d:.*?print 2\n\d:.*?print 4/)
  end

  it 'should apply --head after --grep' do
    @hist.push "puts  1"
    @hist.push "print 2"
    @hist.push "puts  3"
    @hist.push "print 4"
    @hist.push "print 5"

    out = @t.eval 'hist --head 2 --grep print'
    expect(out.each_line.count).to eq 2
    expect(out).to match(/\d:.*?print 2\n\d:.*?print 4/)
  end

  # strangeness in this test is due to bug in Readline::HISTORY not
  # always registering first line of input
  it 'should return first N lines in history with --head switch' do
    ("a".."z").each do |v|
      @hist.push v
    end

    out = @t.eval 'hist --head 4'
    expect(out.each_line.count).to eq 4
    expect(out).to match(/a\n\d+:.*b\n\d+:.*c/)
  end

  # strangeness in this test is due to bug in Readline::HISTORY not
  # always registering first line of input
  it 'should show lines between lines A and B with the --show switch' do
    ("a".."z").each do |v|
      @hist.push v
    end

    out = @t.eval 'hist --show 1..4'
    expect(out.each_line.count).to eq 4
    expect(out).to match(/b\n\d+:.*c\n\d+:.*d/)
  end

  it 'should show lines between offsets A and B with the --show switch' do
    ("a".."f").each do |v|
      @hist.push v
    end

    out = @t.eval 'hist --show -4..-2'
    expect(out).to eq "3: c\n4: d\n5: e\n"
  end

  it "should store a call with `--replay` flag" do
    @t.eval ":banzai"
    @t.eval "hist --replay 1"
    expect(@t.eval("hist")).to match(/hist --replay 1/)
  end

  it "should not contain lines produced by `--replay` flag" do
    @t.eval ":banzai"
    @t.eval ":geronimo"
    @t.eval ":huzzah"
    @t.eval("hist --replay 1..3")

    output = @t.eval("hist")
    expect(output).to eq "1: :banzai\n2: :geronimo\n3: :huzzah\n4: hist --replay 1..3\n"
  end

  it(
    "raises CommandError when index of `--replay` points out to another " \
    "`hist --replay`"
  ) do
    @t.eval ":banzai"
    @t.eval "hist --replay 1"

    expect { @t.eval "hist --replay 2" }.to raise_error(
      Pry::CommandError,
      /Replay index 2 points out to another replay call: `hist --replay 1`/
    )
  end

  it "should disallow execution of `--replay <i>` when CommandError raised" do
    @t.eval "a = 0"
    @t.eval "a += 1"
    @t.eval "hist --replay 2"
    expect { @t.eval "hist --replay 3" }.to raise_error Pry::CommandError
    expect(@t.eval("a")).to eq 2
    expect(@t.eval("hist").lines.to_a.size).to eq 5
  end

  it "excludes Pry commands from the history with `-e` switch" do
    @hist.push('a = 20')
    @hist.push('ls')
    expect(pry_eval('hist -e')).to eq "1: a = 20\n"
  end

  describe "sessions" do
    before do
      @old_file = Pry.config.history_file
      Pry.config.history_file = File.expand_path('spec/fixtures/pry_history')
      @hist.load
    end

    after do
      Pry.config.history_file = @old_file
    end

    it "displays history only for current session" do
      @hist.push('hello')
      @hist.push('world')

      expect(@t.eval('hist')).to match(/1:\shello\n2:\sworld/)
    end

    it "displays all history (including the current sesion) with `--all` switch" do
      @hist.push('goodbye')
      @hist.push('world')

      output = @t.eval('hist --all')
      expect(output).to match(/1:\s:athos\n2:\s:porthos\n3:\s:aramis\n/)
      expect(output).to match(/4:\sgoodbye\n5:\sworld/)
    end

    it "should not display histignore words in history" do
      Pry.config.history_ignorelist = [
        "well",
        "hello",
        "beautiful",
        /show*/,
        "exit"
      ]

      @hist.push("well")
      @hist.push("hello")
      @hist.push("beautiful")
      @hist.push("why")
      @hist.push("so")
      @hist.push("serious?")
      @hist.push("show-method")
      @hist.push("exit")

      output = @t.eval("hist")
      expect(output).to match(/1:\swhy\n2:\sso\n3:\sserious\?\n/)
    end
  end
end
