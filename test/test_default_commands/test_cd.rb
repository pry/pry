require 'helper'

describe 'Pry::DefaultCommands::Cd' do
  after do
    Pad.clear
  end

  describe 'state' do
    it 'should not to be set up in fresh instance' do
      instance = nil
      redirect_pry_io(InputTester.new("cd", "exit-all")) do
        instance = Pry.new
        instance.repl
      end

      instance.command_state["cd"].old_binding.should == nil
      instance.command_state["cd"].append.should == nil
    end
  end

  describe 'old binding toggling with `cd -`' do
    describe 'when an error was raised' do
      it 'should ensure cd @ raises SyntaxError' do
        mock_pry("cd @").should =~ /SyntaxError/
      end

      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd @", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.should == nil
        instance.command_state["cd"].append.should == nil

        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd @", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == false

        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd @", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :mon_dogg
        instance.command_state["cd"].append.should == true
      end
    end

    describe 'when using simple cd syntax' do
      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :mon_dogg
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with multple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == false
      end
    end

    describe "when using complex cd syntax" do
      it 'should toggle with a complex path (simple case)' do
        o = Object.new
        redirect_pry_io(InputTester.new("cd 1/2/3", "Pad.first = _pry_.binding_stack.dup",
                                        "cd -", "Pad.second = _pry_.binding_stack.dup","exit-all")) do
          Pry.start(o)
        end

        Pad.first.map { |v| v.eval('self') }.should == [o, 1, 2, 3]
        Pad.second.map { |v| v.eval('self') }.should == [o]
      end

      it 'should toggle with a complex path (more complex case)' do
        o = Object.new
        redirect_pry_io(InputTester.new("cd 1/2/3", "cd ../4", "Pad.first = _pry_.binding_stack.dup",
                                        "cd -", "Pad.second = _pry_.binding_stack.dup","exit-all")) do
          Pry.start(o)
        end

        Pad.first.map { |v| v.eval('self') }.should == [o, 1, 2, 4]
        Pad.second.map { |v| v.eval('self') }.should == [o, 1, 2, 4, 3]
      end
    end

    describe 'series of cd calls' do
      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd 42", "cd :john_dogg", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == 42
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd 42", "cd :john_dogg", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with multple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd 42", "cd :john_dogg", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == 42
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with fuzzy `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :mon_dogg", "cd -", "cd 42", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == 42
        instance.command_state["cd"].append.should == true
      end

    end

    describe 'when using cd ..' do
      before do
        $obj = Object.new
        $obj.instance_variable_set(:@x, 66)
        $obj.instance_variable_set(:@y, 79)
      end

      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ..", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == true

        redirect_pry_io(InputTester.new("cd :john_dogg", "cd $obj/@x/../@y", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ..", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == false

        redirect_pry_io(InputTester.new("cd :john_dogg", "cd $obj/@x/../@y", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == 79
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with multiple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ..", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == true

        redirect_pry_io(InputTester.new("cd :john_dogg", "cd $obj/@x/../@y", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == false
      end
    end

    describe 'when using cd ::' do
      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ::", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ::", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with multiple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd ::", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == false
      end
    end

    describe 'when using cd /' do
      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd /", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd /", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == TOPLEVEL_BINDING.eval("self")
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with multiple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd /", "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :john_dogg
        instance.command_state["cd"].append.should == true
      end
    end

    describe 'when using ^D (Control-D) key press' do
      before do
        @control_d = "Pry::DEFAULT_CONTROL_D_HANDLER.call('', _pry_)"
      end

      it 'should keep correct old binding' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd :mon_dogg",
                                        "cd :kyr_dogg", @control_d, "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :kyr_dogg
        instance.command_state["cd"].append.should == true
      end

      it 'should toggle with a single `cd -` call' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd :mon_dogg",
                                        "cd :kyr_dogg", @control_d, "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :mon_dogg
        instance.command_state["cd"].append.should == false
      end

      it 'should toggle with multiple `cd -` calls' do
        instance = nil
        redirect_pry_io(InputTester.new("cd :john_dogg", "cd :mon_dogg",
                                        "cd :kyr_dogg", @control_d, "cd -", "cd -", "exit-all")) do
          instance = Pry.new
          instance.repl
        end

        instance.command_state["cd"].old_binding.eval("self").should == :kyr_dogg
        instance.command_state["cd"].append.should == true
      end
    end

    it 'should not toggle when there is no old binding' do
      o = Object.new
      redirect_pry_io(InputTester.new("cd -", "Pad.cs = _pry_.command_state['cd']", "exit-all")) do
        Pry.start(o)
      end

      Pad.cs.old_binding.should == nil
      Pad.cs.append.should == nil

      redirect_pry_io(InputTester.new("cd -", "cd -", "Pad.cs = _pry_.command_state['cd']", "exit-all")) do
        Pry.start(o)
      end

      Pad.cs.old_binding.should == nil
      Pad.cs.append.should == nil
    end
  end

  it 'should cd into simple input' do
    b = Pry.binding_for(Object.new)
    b.eval("x = :mon_ouie")

    redirect_pry_io(InputTester.new("cd x", "$obj = self", "exit-all")) do
      b.pry
    end

    $obj.should == :mon_ouie
  end

  it 'should break out of session with cd ..' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd ..", "$outer = self", "exit-all")) do
      b.pry
    end
    $inner.should == :inner
    $outer.should == :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    b = Pry.binding_for(Object.new)
    input = InputTester.new "cd ..", "$obj = self", "exit-all"

    redirect_pry_io(input) do
      b.pry
    end

    $obj.should == b.eval("self")
  end

  it 'should break out to outer-most session with cd /' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd /", "$outer = self", "exit-all")) do
      b.pry
    end
    $inner.should == :inner
    $five.should == 5
    $outer.should == :outer
  end

  it 'should break out to outer-most session with just cd (no args)' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd", "$outer = self", "exit-all")) do
      b.pry
    end
    $inner.should == :inner
    $five.should == 5
    $outer.should == :outer
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == 66
  end

  it 'should cd into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x/", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == 66
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj", "local = :local", "cd @x", "cd ../local", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == :local
  end

  it 'should cd into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x/..", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 2
    $result[1].eval('self').should == $obj
  end

  it 'should cd into an object and its ivar and back and then into another ivar using cd obj/@ivar/../@y syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)
    $obj.instance_variable_set(:@y, 79)

    redirect_pry_io(InputTester.new("cd $obj/@x/../@y", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == 79
  end

  it 'should cd back to top-level and then into another ivar using cd /@ivar/ syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)
    TOPLEVEL_BINDING.eval('@z = 20')

    redirect_pry_io(InputTester.new("cd $obj/@x/", "cd /@z", "$result = _pry_.binding_stack.dup", "exit-all")) do
      Pry.start
    end
    $result.size.should == 2
    $result[1].eval('self').should == 20
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    redirect_pry_io(InputTester.new("cd ::", "$obj = self", "exit-all")) do
      5.pry
    end
    $obj.should == TOPLEVEL_BINDING.eval('self')
  end

  it 'should cd into complex input (with spaces)' do
    o = Object.new
    def o.hello(x, y, z)
      :mon_ouie
    end

    redirect_pry_io(InputTester.new("cd hello 1, 2, 3", "$obj = self", "exit-all")) do
      o.pry
    end
    $obj.should == :mon_ouie
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
