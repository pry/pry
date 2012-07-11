require 'helper'

describe 'Pry::DefaultCommands::Cd' do
  before do
    @o, @obj = Object.new, Object.new
    @obj.instance_variable_set(:@x, 66)
    @obj.instance_variable_set(:@y, 79)
    @o.instance_variable_set(:@obj, @obj)

    # The `@bs` Enumerator yields strings for tests that require binding stack
    # checkings (for example,Pad.bs1, Pad.bs2 and so on).
    @bs = Enumerator.new do |y|
      n = 0
      loop { y << "Pad.bs#{n+=1} = _pry_.binding_stack.dup" }
    end

    # Same as `@bs`, but for command state's old stack.
    @os = Enumerator.new do |y|
      n = 0
      loop { y << "Pad.os#{n+=1} = _pry_.command_state['cd'].old_stack.dup" }
    end

    @self  = "Pad.self = self"
    @inner = "Pad.inner = self"
    @outer = "Pad.outer = self"
  end

  after do
    Pad.clear
  end

  describe 'state' do
    it 'should not to be set up in fresh instance' do
      redirect_pry_io(InputTester.new(@os.next, "exit-all")) do
        Pry.start(@o)
      end

      Pad.os1.should == nil
    end
  end

  describe 'old stack toggling with `cd -`' do
    describe 'in fresh pry instance' do
      it 'should not toggle when there is no old stack' do
        redirect_pry_io(InputTester.new("cd -", @bs.next, "cd -",
                                         @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval("self") }.should == [@o]
        Pad.bs2.map { |v| v.eval("self") }.should == [@o]
      end
    end

    describe 'when an error was raised' do
      it 'should ensure cd @ raises SyntaxError' do
        mock_pry("cd @").should =~ /SyntaxError/
      end

      it 'should not toggle and should keep correct old stack' do
        redirect_pry_io(InputTester.new("cd @", @os.next, "cd -", @os.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.os1.should == []
        Pad.os2.should == []
      end

      it 'should not toggle and should keep correct current binding stack' do
        redirect_pry_io(InputTester.new("cd @", @bs.next, "cd -",
                                         @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval("self") }.should == [@o]
        Pad.bs2.map { |v| v.eval("self") }.should == [@o]
      end
    end

    describe 'when using simple cd syntax' do
      it 'should toggle' do
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd -", @bs.next,
                                        "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval("self") }.should == [@o]
        Pad.bs2.map { |v| v.eval("self") }.should == [@o, :mon_dogg]
      end
    end

    describe "when using complex cd syntax" do
      it 'should toggle with a complex path (simple case)' do
        redirect_pry_io(InputTester.new("cd 1/2/3", "cd -", @bs.next,
                                        "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, 1, 2, 3]
      end

      it 'should toggle with a complex path (more complex case)' do
        redirect_pry_io(InputTester.new("cd 1/2/3", "cd ../4", "cd -",
                                        @bs.next, "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o, 1, 2, 3]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, 1, 2, 4]
      end
    end

    describe 'series of cd calls' do
      it 'should toggle with fuzzy `cd -` calls' do
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd -", "cd 42", "cd -",
                                        @bs.next, "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, 42]
      end
    end

    describe 'when using cd ..' do
      it 'should toggle with a simple path' do
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ..", @bs.next,
                                        "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, :john_dogg]
      end

      it 'should toggle with a complex path' do
        redirect_pry_io(InputTester.new("cd 1/2/3/../4", "cd -", @bs.next,
                                        "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, 1, 2, 4]
      end
    end

    describe 'when using cd ::' do
      it 'should toggle' do
        redirect_pry_io(InputTester.new("cd ::", "cd -", @bs.next,
                                        "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, TOPLEVEL_BINDING.eval("self")]
      end
    end

    describe 'when using cd /' do
      it 'should toggle' do
        redirect_pry_io(InputTester.new("cd /", "cd -", @bs.next, "cd :john_dogg",
                                        "cd /", "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, :john_dogg]
      end
    end

    describe 'when using ^D (Control-D) key press' do
      before do
        @control_d = "Pry::DEFAULT_CONTROL_D_HANDLER.call('', _pry_)"
      end

      it 'should keep correct old binding' do
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd :mon_dogg",
                                        "cd :kyr_dogg", @control_d, @bs.next,
                                        "cd -", @bs.next, "cd -", @bs.next, "exit-all")) do
          Pry.start(@o)
        end

        Pad.bs1.map { |v| v.eval('self') }.should == [@o, :john_dogg, :mon_dogg]
        Pad.bs2.map { |v| v.eval('self') }.should == [@o, :john_dogg, :mon_dogg, :kyr_dogg]
        Pad.bs3.map { |v| v.eval('self') }.should == [@o, :john_dogg, :mon_dogg]
      end
    end
  end

  it 'should cd into simple input' do
    redirect_pry_io(InputTester.new("cd :mon_ouie", @inner, "exit-all")) do
      Pry.start(@o)
    end

    Pad.inner.should == :mon_ouie
  end

  it 'should break out of session with cd ..' do
    redirect_pry_io(InputTester.new("cd :inner", @inner, "cd ..", @outer, "exit-all")) do
      Pry.start(:outer)
    end

    Pad.inner.should == :inner
    Pad.outer.should == :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    redirect_pry_io(InputTester.new("cd ..", @self, "exit-all")) do
      Pry.start(@o)
    end

    Pad.self.should == @o
  end

  it 'should break out to outer-most session with cd /' do
    redirect_pry_io(InputTester.new("cd :inner", @inner, "cd 5", "Pad.five = self",
                                    "cd /", @outer, "exit-all")) do
      Pry.start(:outer)
    end

    Pad.inner.should == :inner
    Pad.five.should == 5
    Pad.outer.should == :outer
  end

  it 'should break out to outer-most session with just cd (no args)' do
    redirect_pry_io(InputTester.new("cd :inner", @inner, "cd 5", "Pad.five = self",
                                    "cd", @outer, "exit-all")) do
      Pry.start(:outer)
    end

    Pad.inner.should == :inner
    Pad.five.should == 5
    Pad.outer.should == :outer
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    redirect_pry_io(InputTester.new("cd @obj/@x", @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, @obj, 66]
  end

  it 'should cd into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    redirect_pry_io(InputTester.new("cd @obj/@x/", @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, @obj, 66]
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    redirect_pry_io(InputTester.new("cd @obj", "local = :local", "cd @x",
                                    "cd ../local", @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, @obj, :local]
  end

  it 'should cd into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    redirect_pry_io(InputTester.new("cd @obj/@x/..", @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, @obj]
  end

  it 'should cd into an object and its ivar and back and then into another ivar using cd obj/@ivar/../@y syntax' do
    redirect_pry_io(InputTester.new("cd @obj/@x/../@y", @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, @obj, 79]
  end

  it 'should cd back to top-level and then into another ivar using cd /@ivar/ syntax' do
    redirect_pry_io(InputTester.new("@z = 20", "cd @obj/@x/", "cd /@z",
                                     @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o, 20]
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    redirect_pry_io(InputTester.new("cd ::", @self, "exit-all")) do
      Pry.start(@o)
    end

    Pad.self.should == TOPLEVEL_BINDING.eval("self")
  end

  it 'should cd into complex input (with spaces)' do
    def @o.hello(x, y, z)
      :mon_ouie
    end

    redirect_pry_io(InputTester.new("cd hello 1, 2, 3", @self, "exit-all")) do
      Pry.start(@o)
    end

    Pad.self.should == :mon_ouie
  end

  it 'should not cd into complex input when it encounters an exception' do
    redirect_pry_io(InputTester.new("cd 1/2/swoop_a_doop/3",
                                    @bs.next, "exit-all")) do
      Pry.start(@o)
    end

    Pad.bs1.map { |v| v.eval("self") }.should == [@o]
  end

  # Regression test for ticket #516.
  #it 'should be able to cd into the Object BasicObject.' do
  #  mock_pry('cd BasicObject.new').should.not =~ /\Aundefined method `__binding__'/
  #end

  # Regression test for ticket #516
  # Possibly move higher up.
  it 'should not fail with undefined BasicObject#is_a?' do
    mock_pry('cd BasicObject.new').should.not =~ /undefined method `is_a\?'/
  end
end
