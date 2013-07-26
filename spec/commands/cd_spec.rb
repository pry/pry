require 'helper'

describe 'cd' do
  before do
    @o, @obj = Object.new, Object.new
    @obj.instance_variable_set(:@x, 66)
    @obj.instance_variable_set(:@y, 79)
    @o.instance_variable_set(:@obj, @obj)

    @t = pry_tester(@o) do
      def assert_binding_stack(other)
        binding_stack.map { |b| b.eval('self') }.should == other
      end

      def binding_stack
        eval '_pry_.binding_stack.dup'
      end

      def command_state
        eval '_pry_.command_state["cd"]'
      end

      def old_stack
        eval '_pry_.command_state["cd"].old_stack.dup'
      end
    end
  end

  describe 'state' do
    it 'should not to be set up in fresh instance' do
      @t.command_state.should.be.nil
    end
  end

  describe 'old stack toggling with `cd -`' do
    describe 'in fresh pry instance' do
      it 'should not toggle when there is no old stack' do
        2.times do
          @t.eval 'cd -'
          @t.assert_binding_stack [@o]
        end
      end
    end

    describe 'when an error was raised' do
      it 'should not toggle and should keep correct stacks' do
        proc {
          @t.eval 'cd %'
        }.should.raise(Pry::CommandError)

        @t.old_stack.should == []
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.old_stack.should == []
        @t.assert_binding_stack [@o]
      end
    end

    describe 'when using simple cd syntax' do
      it 'should toggle' do
        @t.eval 'cd :mon_dogg', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, :mon_dogg]
      end
    end

    describe "when using complex cd syntax" do
      it 'should toggle with a complex path (simple case)' do
        @t.eval 'cd 1/2/3', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, 1, 2, 3]
      end

      it 'should toggle with a complex path (more complex case)' do
        @t.eval 'cd 1/2/3', 'cd ../4', 'cd -'
        @t.assert_binding_stack [@o, 1, 2, 3]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, 1, 2, 4]
      end
    end

    describe 'series of cd calls' do
      it 'should toggle with fuzzy `cd -` calls' do
        @t.eval 'cd :mon_dogg', 'cd -', 'cd 42', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, 42]
      end
    end

    describe 'when using cd ..' do
      it 'should toggle with a simple path' do
        @t.eval 'cd :john_dogg', 'cd ..'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, :john_dogg]
      end

      it 'should toggle with a complex path' do
        @t.eval 'cd 1/2/3/../4', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, 1, 2, 4]
      end
    end

    describe 'when using cd ::' do
      it 'should toggle' do
        @t.eval 'cd ::', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, TOPLEVEL_BINDING.eval('self')]
      end
    end

    describe 'when using cd /' do
      it 'should toggle' do
        @t.eval 'cd /', 'cd -'
        @t.assert_binding_stack [@o]

        @t.eval 'cd :john_dogg', 'cd /', 'cd -'
        @t.assert_binding_stack [@o, :john_dogg]
      end
    end

    describe 'when using ^D (Control-D) key press' do
      it 'should keep correct old binding' do
        @t.eval 'cd :john_dogg', 'cd :mon_dogg', 'cd :kyr_dogg',
          'Pry::DEFAULT_CONTROL_D_HANDLER.call("", _pry_)'
        @t.assert_binding_stack [@o, :john_dogg, :mon_dogg]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, :john_dogg, :mon_dogg, :kyr_dogg]

        @t.eval 'cd -'
        @t.assert_binding_stack [@o, :john_dogg, :mon_dogg]
      end
    end
  end

  it 'should cd into simple input' do
    @t.eval 'cd :mon_ouie'
    @t.eval('self').should == :mon_ouie
  end

  it 'should break out of session with cd ..' do
    @t.eval 'cd :outer', 'cd :inner'
    @t.eval('self').should == :inner

    @t.eval 'cd ..'
    @t.eval('self').should == :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    @t.eval 'cd ..'
    @t.eval('self').should == @o
  end

  it 'should break out to outer-most session with cd /' do
    @t.eval 'cd :inner'
    @t.eval('self').should == :inner

    @t.eval 'cd 5'
    @t.eval('self').should == 5

    @t.eval 'cd /'
    @t.eval('self').should == @o
  end

  it 'should break out to outer-most session with just cd (no args)' do
    @t.eval 'cd :inner'
    @t.eval('self').should == :inner

    @t.eval 'cd 5'
    @t.eval('self').should == 5

    @t.eval 'cd'
    @t.eval('self').should == @o
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    @t.eval 'cd @obj/@x'
    @t.assert_binding_stack [@o, @obj, 66]
  end

  it 'should cd into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    @t.eval 'cd @obj/@x/'
    @t.assert_binding_stack [@o, @obj, 66]
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    @t.eval 'cd @obj', 'local = :local', 'cd @x', 'cd ../local'
    @t.assert_binding_stack [@o, @obj, :local]
  end

  it 'should cd into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    @t.eval 'cd @obj/@x/..'
    @t.assert_binding_stack [@o, @obj]
  end

  it 'should cd into an object and its ivar and back and then into another ivar using cd obj/@ivar/../@y syntax' do
    @t.eval 'cd @obj/@x/../@y'
    @t.assert_binding_stack [@o, @obj, 79]
  end

  it 'should cd back to top-level and then into another ivar using cd /@ivar/ syntax' do
    @t.eval '@z = 20', 'cd @obj/@x/', 'cd /@z'
    @t.assert_binding_stack [@o, 20]
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    @t.eval 'cd ::'
    @t.eval('self').should == TOPLEVEL_BINDING.eval('self')
  end

  it 'should cd into complex input (with spaces)' do
    def @o.hello(x, y, z)
      :mon_ouie
    end

    @t.eval 'cd hello 1, 2, 3'
    @t.eval('self').should == :mon_ouie
  end

  it 'should not cd into complex input when it encounters an exception' do
    proc {
      @t.eval 'cd 1/2/swoop_a_doop/3'
    }.should.raise(Pry::CommandError)

    @t.assert_binding_stack [@o]
  end

  # Regression test for ticket #516.
  # FIXME: This is actually broken.
  # it 'should be able to cd into the Object BasicObject' do
  #   proc {
  #     @t.eval 'cd BasicObject.new'
  #   }.should.not.raise
  # end
end
