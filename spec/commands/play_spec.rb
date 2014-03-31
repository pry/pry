# This command needs a TONNE more tests for it, but i can't figure out
# how to do them yet, and i really want to release. Sorry. Someone
# come along and do a better job.

require_relative '../helper'

describe "play" do
  before do
    @o = Object.new
    @t = pry_tester(@o)
  end

  describe "with an argument" do

    # can't think of a f*cking way to test this!!
    describe "implied file" do
      # it 'should play from the file associated with the current binding' do
      #   # require 'fixtures/play_helper'
      # end


      # describe "integer" do
      #   it "should process one line from _pry_.last_file" do
      #     @t.process_command 'play --lines 1', @eval_str
      #     @eval_str.should =~ /bing = :bing\n/
      #   end
      # end

      # describe "range" do
      #   it "should process multiple lines at once from _pry_.last_file" do
      #     @t.process_command 'play --lines 1..3', @eval_str
      #     [/bing = :bing\n/, /bang = :bang\n/, /bong = :bong\n/].each { |str|
      #       @eval_str.should =~ str
      #     }
      #   end
    end
  end

  describe "playing a file" do
    it 'should play a file' do
      @t.process_command 'play spec/fixtures/whereami_helper.rb'
      @t.eval_string.should == unindent(<<-STR)
        class Cor
          def a; end
          def b; end
          def c; end
          def d; end
        end
      STR
    end


    it 'should output file contents with print option' do
      @t.process_command 'play --print spec/fixtures/whereami_helper.rb'
      @t.last_output.should == unindent(<<-STR)
        1: class Cor
        2:   def a; end
        3:   def b; end
        4:   def c; end
        5:   def d; end
        6: end
      STR
    end
  end

  describe "whatever" do
    before do
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

    it 'has pretty error messages when -d cant find object' do
      lambda { @t.process_command "play -d sdfsdf" }.should.raise(Pry::CommandError).message.should.match(/Cannot locate/)
    end

    it 'should play a method (a single line)' do
      @t.process_command 'play test_method --lines 2'
      @t.eval_string.should == ":test_method_content\n"
    end

    it 'should properly reindent lines' do
      def @o.test_method
        'hello world'
      end

      @t.process_command 'play test_method --lines 2'
      @t.eval_string.should == "'hello world'\n"
    end

    it 'should APPEND to the input buffer when playing a method line, not replace it' do
      @t.eval_string = unindent(<<-STR)
        def another_test_method
      STR

      @t.process_command 'play test_method --lines 2'

      @t.eval_string.should == unindent(<<-STR)
        def another_test_method
          :test_method_content
      STR
    end

    it 'should play a method (multiple lines)' do
      def @o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      @t.process_command 'play test_method --lines 3..4'
      @t.eval_string.should == unindent(<<-STR, 0)
        @var1 = 20
        @var2 = 30
      STR
    end

    describe "play -i" do
      it 'should play multi-ranged input expressions' do
        a = b = c = d = e = 0
        redirect_pry_io(InputTester.new('a += 1', 'b += 1',
                                        'c += 1', 'd += 1', 'e += 1',
                                        "play -i 1..3"), StringIO.new) do
          binding.pry
        end

        [a, b, c].all? { |v| v.should == 2 }
        d.should == 1
      end
    end

    describe "play -e" do
      it 'should run an expression from given line number' do
        def @o.test_method
          @s = [
            1,2,3,
            4,5,6
          ]
        end

        @t.process_command 'play test_method -e 2'
        @t.eval_string.should == unindent(<<-STR, 0)
          @s = [
            1,2,3,
            4,5,6
          ]
        STR
      end
    end
  end
end
