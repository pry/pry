require 'helper'

describe "play" do
  before do
    @t = pry_tester
    @eval_str = ''
  end

  describe "with an argument" do
    describe "string variable" do
      it "without --lines switch" do
        @t.eval 'x = "\"hello\""'
        @t.process_command 'play x', @eval_str
        @eval_str.should == '"hello"'
      end

      it 'using --lines switch to select what to play' do
        @t.eval 'x = "\"hello\"\n\"goodbye\"\n\"love\""'
        @t.process_command 'play x --lines 1', @eval_str
        @eval_str.should == "\"hello\"\n"
      end
    end

    describe "numbers" do
      before do
        @tempfile = Tempfile.new(%w|pry .rb|)
        @tempfile.puts <<-EOS
          bing = :bing
          bang = :bang
          bong = :bong
        EOS
        @tempfile.flush

        @t.eval %|_pry_.last_file = "#{ @tempfile.path }"|
      end

      after do
        @tempfile.close(true)
      end

      describe "integer" do
        it "should process one line from _pry_.last_file" do
          @t.process_command 'play 1', @eval_str
          @eval_str.should =~ /bing = :bing\n/
        end
      end

      describe "range" do
        it "should process multiple lines at once from _pry_.last_file" do
          @t.process_command 'play 1..3', @eval_str
          [/bing = :bing\n/, /bang = :bang\n/, /bong = :bong\n/].each { |str|
            @eval_str.should =~ str
          }
        end
      end
    end

    describe "malformed" do
      it "should return nothing" do
        @t.process_command 'play 69', @eval_str
        @eval_str.should == ''
        lambda { @t.process_command('play zZz') }.should.raise Pry::CommandError
      end
    end
  end

  describe "without argument (switches only)" do
    before do
      @o = Object.new
      def @o.test_method
        :test_method_content
      end
    end

    it 'should play documentation with the -d switch' do
      # @v = 10
      # @y = 20
      def @o.test_method
        :test_method_content
      end

      pry_tester(@o).process_command 'play -d test_method', @eval_str

      @eval_str.should == unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should restrict -d switch with --lines' do
      # @x = 0
      # @v = 10
      # @y = 20
      # @z = 30
      def @o.test_method
        :test_method_content
      end

      pry_tester(@o).process_command 'play -d test_method --lines 2..3', @eval_str

      @eval_str.should == unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should play a method with the -m switch (a single line)' do
      pry_tester(@o).process_command 'play -m test_method --lines 2', @eval_str
      @eval_str.should == "  :test_method_content\n"
    end

    it 'should APPEND to the input buffer when playing a line with play -m, not replace it' do
      @eval_str = unindent(<<-STR)
        def another_test_method
      STR

      pry_tester(@o).process_command 'play -m test_method --lines 2', @eval_str

      @eval_str.should == unindent(<<-STR)
        def another_test_method
          :test_method_content
      STR
    end

    it 'should play a method with the -m switch (multiple line)' do
      def @o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      pry_tester(@o).process_command 'play -m test_method --lines 3..4', @eval_str

      @eval_str.should == unindent(<<-STR, 2)
        @var1 = 20
        @var2 = 30
      STR
    end
  end
end
