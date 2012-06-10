require 'helper'

describe 'Pry::DefaultCommands::Cd' do
  after do
    $obj = nil
  end

  it 'should cd into simple input' do
    b = Pry.binding_for(Object.new)
    b.eval("x = :mon_ouie")

    redirect_pry_io(InputTester.new("cd x", "$obj = self", "exit-all"), StringIO.new) do
      b.pry
    end

    $obj.should == :mon_ouie
  end

  it 'should break out of session with cd ..' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd ..", "$outer = self", "exit-all"), StringIO.new) do
      b.pry
    end
    $inner.should == :inner
    $outer.should == :outer
  end

  it "should not leave the REPL session when given 'cd ..'" do
    b = Pry.binding_for(Object.new)
    input = InputTester.new "cd ..", "$obj = self", "exit-all"

    redirect_pry_io(input, StringIO.new) do
      b.pry
    end

    $obj.should == b.eval("self")
  end

  it 'should break out to outer-most session with cd /' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd /", "$outer = self", "exit-all"), StringIO.new) do
      b.pry
    end
    $inner.should == :inner
    $five.should == 5
    $outer.should == :outer
  end

  it 'should break out to outer-most session with just cd (no args)' do
    b = Pry.binding_for(:outer)
    b.eval("x = :inner")

    redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd", "$outer = self", "exit-all"), StringIO.new) do
      b.pry
    end
    $inner.should == :inner
    $five.should == 5
    $outer.should == :outer
  end

  it 'should cd into an object and its ivar using cd obj/@ivar syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == 66
  end

  it 'should cd into an object and its ivar using cd obj/@ivar/ syntax (note following /)' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x/", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == 66
  end

  it 'should cd into previous object and its local using cd ../local syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj", "local = :local", "cd @x", "cd ../local", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
      Pry.start
    end
    $result.size.should == 3
    $result[1].eval('self').should == $obj
    $result[2].eval('self').should == :local
  end

  it 'should cd into an object and its ivar and back again using cd obj/@ivar/.. syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)

    redirect_pry_io(InputTester.new("cd $obj/@x/..", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
      Pry.start
    end
    $result.size.should == 2
    $result[1].eval('self').should == $obj
  end

  it 'should cd into an object and its ivar and back and then into another ivar using cd obj/@ivar/../@y syntax' do
    $obj = Object.new
    $obj.instance_variable_set(:@x, 66)
    $obj.instance_variable_set(:@y, 79)

    redirect_pry_io(InputTester.new("cd $obj/@x/../@y", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
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

    redirect_pry_io(InputTester.new("cd $obj/@x/", "cd /@z", "$result = _pry_.binding_stack.dup", "exit-all"), StringIO.new) do
      Pry.start
    end
    $result.size.should == 2
    $result[1].eval('self').should == 20
  end

  it 'should start a session on TOPLEVEL_BINDING with cd ::' do
    redirect_pry_io(InputTester.new("cd ::", "$obj = self", "exit-all"), StringIO.new) do
      5.pry
    end
    $obj.should == TOPLEVEL_BINDING.eval('self')
  end

  it 'should cd into complex input (with spaces)' do
    o = Object.new
    def o.hello(x, y, z)
      :mon_ouie
    end

    redirect_pry_io(InputTester.new("cd hello 1, 2, 3", "$obj = self", "exit-all"), StringIO.new) do
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
