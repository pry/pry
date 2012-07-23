require 'helper'

module CdTestHelpers
  def binding_stack
    evaluate_ruby '_pry_.binding_stack.dup'
  end

  def assert_binding_stack(other)
    binding_stack.map { |b| b.eval('self') }.should == other
  end

  def command_state
    evaluate_ruby '_pry_.command_state["cd"]'
  end

  def old_stack
    evaluate_ruby '_pry_.command_state["cd"].old_stack.dup'
  end

  def evaluate_self
    evaluate_ruby 'self'
  end

  def process_commands(*args)
    args.flatten.each do |cmd|
      @pry.process_command cmd
    end
  end

  def evaluate_ruby(ruby)
    @pry.evaluate_ruby ruby
  end
end

describe 'Pry::DefaultCommands::Cd' do
  before do
    extend CdTestHelpers

    @o, @obj = Object.new, Object.new
    @obj.instance_variable_set(:@x, 66)
    @obj.instance_variable_set(:@y, 79)
    @o.instance_variable_set(:@obj, @obj)

    @pry = Pry.new
    @pry.binding_stack << Pry.binding_for(@o)
  end

  describe 'state' do
    it 'should not to be set up in fresh instance' do
      command_state.should.be.nil
    end
  end

  describe 'old stack toggling with `cd -`' do
    describe 'in fresh pry instance' do
      it 'should not toggle when there is no old stack' do
        2.times do
          process_commands 'cd -'
          assert_binding_stack [@o]
        end
      end
    end

    describe 'when an error was raised' do
      it 'should not toggle and should keep correct stacks' do
        proc {
          process_commands 'cd @'
        }.should.raise(Pry::CommandError)

        old_stack.should == []
        assert_binding_stack [@o]

        process_commands 'cd -'
        old_stack.should == []
        assert_binding_stack [@o]
      end
    end

    describe 'when using simple cd syntax' do
      it 'should toggle' do
        process_commands 'cd :mon_dogg', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, :mon_dogg]
      end
    end

    describe "when using complex cd syntax" do
      it 'should toggle with a complex path (simple case)' do
        process_commands 'cd 1/2/3', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, 1, 2, 3]
      end

      it 'should toggle with a complex path (more complex case)' do
        process_commands 'cd 1/2/3', 'cd ../4', 'cd -'
        assert_binding_stack [@o, 1, 2, 3]

        process_commands 'cd -'
        assert_binding_stack [@o, 1, 2, 4]
      end
    end

    describe 'series of cd calls' do
      it 'should toggle with fuzzy `cd -` calls' do
        process_commands 'cd :mon_dogg', 'cd -', 'cd 42', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, 42]
      end
    end

    describe 'when using cd ..' do
      it 'should toggle with a simple path' do
        process_commands 'cd :john_dogg', 'cd ..'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, :john_dogg]
      end

      it 'should toggle with a complex path' do
        process_commands 'cd 1/2/3/../4', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, 1, 2, 4]
      end
    end

    describe 'when using cd ::' do
      it 'should toggle' do
        process_commands 'cd ::', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd -'
        assert_binding_stack [@o, TOPLEVEL_BINDING.eval('self')]
      end
    end

    describe 'when using cd /' do
      it 'should toggle' do
        process_commands 'cd /', 'cd -'
        assert_binding_stack [@o]

        process_commands 'cd :john_dogg', 'cd /', 'cd -'
        assert_binding_stack [@o, :john_dogg]
      end
    end

    describe 'when using ^D (Control-D) key press' do
      it 'should keep correct old binding' do
        process_commands 'cd :john_dogg', 'cd :mon_dogg', 'cd :kyr_dogg'
        evaluate_ruby 'Pry::DEFAULT_CONTROL_D_HANDLER.call("", _pry_)'
        assert_binding_stack [@o, :john_dogg, :mon_dogg]

        process_commands 'cd -'
        assert_binding_stack [@o, :john_dogg, :mon_dogg, :kyr_dogg]

        process_commands 'cd -'
        assert_binding_stack [@o, :john_dogg, :mon_dogg]
      end
    end
  end

  it 'should cd into simple input' do
    process_commands 'cd :mon_ouie'
    evaluate_self.should == :mon_ouie
  end

  it 'should break out of session with cd ..' do
    process_commands 'cd :outer', 'cd :inner'
    evaluate_self.should == :inner

    process_commands 'cd ..'
    evaluate_self.should == :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    process_commands 'cd ..'
    evaluate_self.should == @o
  end

  it 'should break out to outer-most session with cd /' do
    process_commands 'cd :inner'
    evaluate_self.should == :inner

    process_commands 'cd 5'
    evaluate_self.should == 5

    process_commands 'cd /'
    evaluate_self.should == @o
  end

  it 'should break out to outer-most session with just cd (no args)' do
    process_commands 'cd :inner'
    evaluate_self.should == :inner

    process_commands 'cd 5'
    evaluate_self.should == 5

    process_commands 'cd'
    evaluate_self.should == @o
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    process_commands 'cd @obj/@x'
    assert_binding_stack [@o, @obj, 66]
  end

  it 'should cd into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    process_commands 'cd @obj/@x/'
    assert_binding_stack [@o, @obj, 66]
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    process_commands 'cd @obj'
    evaluate_ruby 'local = :local'
    process_commands 'cd @x', 'cd ../local'
    assert_binding_stack [@o, @obj, :local]
  end

  it 'should cd into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    process_commands 'cd @obj/@x/..'
    assert_binding_stack [@o, @obj]
  end

  it 'should cd into an object and its ivar and back and then into another ivar using cd obj/@ivar/../@y syntax' do
    process_commands 'cd @obj/@x/../@y'
    assert_binding_stack [@o, @obj, 79]
  end

  it 'should cd back to top-level and then into another ivar using cd /@ivar/ syntax' do
    evaluate_ruby '@z = 20'
    process_commands 'cd @obj/@x/', 'cd /@z'
    assert_binding_stack [@o, 20]
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    process_commands 'cd ::'
    evaluate_self.should == TOPLEVEL_BINDING.eval('self')
  end

  it 'should cd into complex input (with spaces)' do
    def @o.hello(x, y, z)
      :mon_ouie
    end

    process_commands 'cd hello 1, 2, 3'
    evaluate_self.should == :mon_ouie
  end

  it 'should not cd into complex input when it encounters an exception' do
    proc {
      process_commands 'cd 1/2/swoop_a_doop/3'
    }.should.raise(Pry::CommandError)

    assert_binding_stack [@o]
  end

  # Regression test for ticket #516.
  # FIXME: This is actually broken.
  # it 'should be able to cd into the Object BasicObject' do
  #   proc {
  #     process_commands 'cd BasicObject.new'
  #   }.should.not.raise
  # end
end
