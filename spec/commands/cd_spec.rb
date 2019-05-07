# frozen_string_literal: true

describe 'cd' do
  before do
    @o = Object.new
    @obj = Object.new
    @obj.instance_variable_set(:@x, 66)
    @obj.instance_variable_set(:@y, 79)
    @o.instance_variable_set(:@obj, @obj)

    @t = pry_tester(@o) do
      def mapped_binding_stack
        binding_stack.map { |b| b.eval('self') }
      end

      def binding_stack
        pry.binding_stack.dup
      end

      def command_state
        pry.commands['cd'].state
      end

      def old_stack
        pry.commands['cd'].state.old_stack.dup
      end
    end
  end

  after { Pry::CommandState.default.reset('cd') }

  describe 'old stack toggling with `cd -`' do
    describe 'in fresh pry instance' do
      it 'should not toggle when there is no old stack' do
        2.times do
          @t.eval 'cd -'
          expect(@t.mapped_binding_stack).to eq [@o]
        end
      end
    end

    describe 'when an error was raised' do
      it 'should not toggle and should keep correct stacks' do
        expect { @t.eval 'cd %' }.to raise_error Pry::CommandError

        expect(@t.old_stack).to eq []
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.old_stack).to eq []
        expect(@t.mapped_binding_stack).to eq [@o]
      end
    end

    describe 'when using simple cd syntax' do
      it 'should toggle' do
        @t.eval 'cd :mon_dogg', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, :mon_dogg]
      end
    end

    describe "when using complex cd syntax" do
      it 'should toggle with a complex path (simple case)' do
        @t.eval 'cd 1/2/3', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, 1, 2, 3]
      end

      it 'should toggle with a complex path (more complex case)' do
        @t.eval 'cd 1/2/3', 'cd ../4', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, 1, 2, 3]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, 1, 2, 4]
      end
    end

    describe 'series of cd calls' do
      it 'should toggle with fuzzy `cd -` calls' do
        @t.eval 'cd :mon_dogg', 'cd -', 'cd 42', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, 42]
      end
    end

    describe 'when using cd ..' do
      it 'should toggle with a simple path' do
        @t.eval 'cd :john_dogg', 'cd ..'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, :john_dogg]
      end

      it 'should toggle with a complex path' do
        @t.eval 'cd 1/2/3/../4', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, 1, 2, 4]
      end
    end

    describe 'when using cd ::' do
      it 'should toggle' do
        @t.eval 'cd ::', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, TOPLEVEL_BINDING.eval('self')]
      end
    end

    describe 'when using cd /' do
      it 'should toggle' do
        @t.eval 'cd /', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o]

        @t.eval 'cd :john_dogg', 'cd /', 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, :john_dogg]
      end
    end

    describe 'when using ^D (Control-D) key press' do
      it 'should keep correct old binding' do
        @t.eval 'cd :john_dogg', 'cd :mon_dogg', 'cd :kyr_dogg',
                'Pry.config.control_d_handler.call(pry_instance)'
        expect(@t.mapped_binding_stack).to eq [@o, :john_dogg, :mon_dogg]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, :john_dogg, :mon_dogg, :kyr_dogg]

        @t.eval 'cd -'
        expect(@t.mapped_binding_stack).to eq [@o, :john_dogg, :mon_dogg]
      end
    end
  end

  it 'should cd into simple input' do
    @t.eval 'cd :mon_ouie'
    expect(@t.eval('self')).to eq :mon_ouie
  end

  it 'should break out of session with cd ..' do
    @t.eval 'cd :outer', 'cd :inner'
    expect(@t.eval('self')).to eq :inner

    @t.eval 'cd ..'
    expect(@t.eval('self')).to eq :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    @t.eval 'cd ..'
    expect(@t.eval('self')).to eq @o
  end

  it 'should break out to outer-most session with cd /' do
    @t.eval 'cd :inner'
    expect(@t.eval('self')).to eq :inner

    @t.eval 'cd 5'
    expect(@t.eval('self')).to eq 5

    @t.eval 'cd /'
    expect(@t.eval('self')).to eq @o
  end

  it 'should break out to outer-most session with just cd (no args)' do
    @t.eval 'cd :inner'
    expect(@t.eval('self')).to eq :inner

    @t.eval 'cd 5'
    expect(@t.eval('self')).to eq 5

    @t.eval 'cd'
    expect(@t.eval('self')).to eq @o
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    @t.eval 'cd @obj/@x'
    expect(@t.mapped_binding_stack).to eq [@o, @obj, 66]
  end

  it 'cds into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    @t.eval 'cd @obj/@x/'
    expect(@t.mapped_binding_stack).to eq [@o, @obj, 66]
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    @t.eval 'cd @obj', 'local = :local', 'cd @x', 'cd ../local'
    expect(@t.mapped_binding_stack).to eq [@o, @obj, :local]
  end

  it 'cds into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    @t.eval 'cd @obj/@x/..'
    expect(@t.mapped_binding_stack).to eq [@o, @obj]
  end

  it(
    'cds into an object and its ivar and back and then into another ivar ' \
    'using cd obj/@ivar/../@y syntax'
  ) do
    @t.eval 'cd @obj/@x/../@y'
    expect(@t.mapped_binding_stack).to eq [@o, @obj, 79]
  end

  it 'should cd back to top-level and then into another ivar using cd /@ivar/ syntax' do
    @t.eval '@z = 20', 'cd @obj/@x/', 'cd /@z'
    expect(@t.mapped_binding_stack).to eq [@o, 20]
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    @t.eval 'cd ::'
    expect(@t.eval('self')).to eq TOPLEVEL_BINDING.eval('self')
  end

  it 'should cd into complex input (with spaces)' do
    def @o.hello(_x, _y, _z) # rubocop:disable Naming/UncommunicativeMethodParamName
      :mon_ouie
    end

    @t.eval 'cd hello 1, 2, 3'
    expect(@t.eval('self')).to eq :mon_ouie
  end

  it 'should not cd into complex input when it encounters an exception' do
    expect { @t.eval 'cd 1/2/swoop_a_doop/3' }.to raise_error Pry::CommandError

    expect(@t.mapped_binding_stack).to eq [@o]
  end

  it 'can cd into an expression containing a string with slashes in it' do
    @t.eval 'cd ["http://google.com"]'
    expect(@t.eval('self')).to eq ["http://google.com"]
  end

  it 'can cd into an expression with division in it' do
    @t.eval 'cd (10/2)/even?'
    expect(@t.eval('self')).to eq false
  end

  # Regression test for ticket #516.
  it 'should be able to cd into the Object BasicObject' do
    expect { @t.eval 'cd BasicObject.new' }.to_not raise_error
  end

  # https://github.com/pry/pry/issues/1596
  it "can cd into objects that redefine #respond_to? to return true" do
    expect { @t.eval('cd Class.new { def respond_to?(m) true end }.new') }
      .to_not raise_error
  end
end
