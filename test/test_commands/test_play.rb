require 'helper'

describe "play" do
  before do
    @t = pry_tester
  end

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
