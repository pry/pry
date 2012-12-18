require 'helper'

describe "play" do
  before do
    @t = pry_tester
  end

  describe "with an argument" do
    describe "string variable" do
      it "without --lines switch" do
        @t.eval 'x = "\"hello\""'
        @t.process_command 'play x'
        @t.eval_string.should == '"hello"'
      end

      it 'using --lines switch to select what to play' do
        @t.eval 'x = "\"hello\"\n\"goodbye\"\n\"love\""'
        @t.process_command 'play x --lines 1'
        @t.eval_string.should == "\"hello\"\n"
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
          @t.process_command 'play 1'
          @t.eval_string.should =~ /bing = :bing\n/
        end
      end

      describe "range" do
        it "should process multiple lines at once from _pry_.last_file" do
          @t.process_command 'play 1..3'
          [/bing = :bing\n/, /bang = :bang\n/, /bong = :bong\n/].each { |str|
            @t.eval_string.should =~ str
          }
        end
      end
    end

    describe "malformed" do
      it "should return nothing" do
        @t.process_command 'play 69'
        @t.eval_string.should == ''
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

      @t = pry_tester(@o)
    end

    it 'should play documentation with the -d switch' do
      # @v = 10
      # @y = 20
      def @o.test_method
        :test_method_content
      end

      @t.process_command 'play -d test_method'
      @t.eval_string.should == unindent(<<-STR)
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

      @t.process_command 'play -d test_method --lines 2..3'
      @t.eval_string.should == unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should play a method with the -m switch (a single line)' do
      @t.process_command 'play -m test_method --lines 2'
      @t.eval_string.should == "  :test_method_content\n"
    end

    it 'should APPEND to the input buffer when playing a line with play -m, not replace it' do
      @t.accept_line 'def another_test_method'
      @t.process_command 'play -m test_method --lines 2'
      @t.eval_string.should == unindent(<<-STR)
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

      @t.process_command 'play -m test_method --lines 3..4'
      @t.eval_string.should == unindent(<<-STR, 2)
        @var1 = 20
        @var2 = 30
      STR
    end
  end
end
