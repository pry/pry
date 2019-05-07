# frozen_string_literal: true

# This command needs a TONNE more tests for it, but i can't figure out
# how to do them yet, and i really want to release. Sorry. Someone
# come along and do a better job.
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
      #   it "should process one line from pry_instance.last_file" do
      #     @t.process_command 'play --lines 1', @eval_str
      #     @eval_str.should =~ /bing = :bing\n/
      #   end
      # end

      # describe "range" do
      #   it "should process multiple lines at once from pry_instance.last_file" do
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
      expect(@t.eval_string).to eq unindent(<<-STR)
        # frozen_string_literal: true
        # rubocop:disable Layout/EmptyLineBetweenDefs
        class Cor
          def a; end
          def b; end
          def c; end
          def d; end
        end
        # rubocop:enable Layout/EmptyLineBetweenDefs
      STR
    end

    it 'should output file contents with print option' do
      @t.process_command 'play --print spec/fixtures/whereami_helper.rb'
      expect(@t.last_output).to eq(
        " 1: \# frozen_string_literal: true\n" \
        " 2: \n" \
        " 3: \# rubocop:disable Layout/EmptyLineBetweenDefs\n" \
        " 4: class Cor\n" \
        " 5:   def a; end\n" \
        " 6:   def b; end\n" \
        " 7:   def c; end\n" \
        " 8:   def d; end\n" \
        " 9: end\n" \
        "10: \# rubocop:enable Layout/EmptyLineBetweenDefs\n"
      )
    end
  end

  describe "whatever" do
    before do
      def @o.test_method
        :test_method_content
      end
    end

    it 'should play documentation with the -d switch' do
      @o.singleton_class.send :remove_method, :test_method

      # @v = 10
      # @y = 20
      def @o.test_method
        :test_method_content
      end

      @t.process_command 'play -d test_method'
      expect(@t.eval_string).to eq unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'should restrict -d switch with --lines' do
      @o.singleton_class.send :remove_method, :test_method

      # @x = 0
      # @v = 10
      # @y = 20
      # @z = 30
      def @o.test_method
        :test_method_content
      end

      @t.process_command 'play -d test_method --lines 2..3'
      expect(@t.eval_string).to eq unindent(<<-STR)
        @v = 10
        @y = 20
      STR
    end

    it 'has pretty error messages when -d cant find object' do
      expect { @t.process_command "play -d sdfsdf" }
        .to raise_error(Pry::CommandError, /Cannot locate/)
    end

    it 'should play a method (a single line)' do
      @t.process_command 'play test_method --lines 2'
      expect(@t.eval_string).to eq ":test_method_content\n"
    end

    it 'should properly reindent lines' do
      @o.singleton_class.send :remove_method, :test_method

      def @o.test_method
        'hello world'
      end

      @t.process_command 'play test_method --lines 2'
      expect(@t.eval_string).to eq "'hello world'\n"
    end

    it 'should APPEND to the input buffer when playing a method line, not replace it' do
      @t.eval_string = unindent(<<-STR)
        def another_test_method
      STR

      @t.process_command 'play test_method --lines 2'

      expect(@t.eval_string).to eq unindent(<<-STR)
        def another_test_method
          :test_method_content
      STR
    end

    it 'should play a method (multiple lines)' do
      @o.singleton_class.send :remove_method, :test_method

      def @o.test_method
        @var0 = 10
        @var1 = 20
        @var2 = 30
        @var3 = 40
      end

      @t.process_command 'play test_method --lines 3..4'
      expect(@t.eval_string).to eq unindent(<<-STR, 0)
        @var1 = 20
        @var2 = 30
      STR
    end

    describe "play -i" do
      it 'should play multi-ranged input expressions' do
        a = b = c = d = e = 0
        redirect_pry_io(
          InputTester.new(
            'a += 1', 'b += 1', 'c += 1', 'd += 1', 'e += 1', 'play -i 1..3'
          ),
          StringIO.new
        ) do
          binding.pry # rubocop:disable Lint/Debugger
        end

        [a, b, c].all? { |v| expect(v).to eq 2 }
        expect(d).to eq 1
        expect(e).to eq 1
      end
    end

    describe "play -e" do
      it 'should run an expression from given line number' do
        @o.singleton_class.send :remove_method, :test_method

        def @o.test_method
          @s = [
            1, 2, 3,
            4, 5, 6
          ]
        end

        @t.process_command 'play test_method -e 2'
        expect(@t.eval_string).to eq unindent(<<-STR, 0)
          @s = [
            1, 2, 3,
            4, 5, 6
          ]
        STR
      end
    end
  end
end
