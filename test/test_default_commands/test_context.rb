require 'helper'

describe "Pry::DefaultCommands::Context" do
  describe "exit-all" do
    it 'should break out of the repl loop of Pry instance (returning target of session)' do
      redirect_pry_io(InputTester.new("exit-all"), StringIO.new) do
        Pry.new.repl(0).should == 0
      end
    end

    it 'should break out of the repl loop of Pry instance wth a user specified value' do
      redirect_pry_io(InputTester.new("exit-all 'message'"), StringIO.new) do
        Pry.new.repl(0).should == 'message'
      end
    end

    it 'should break of the repl loop even if multiple bindings still on stack' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "exit-all 'message'"), StringIO.new) do
        ins = Pry.new.tap { |v| v.repl(0).should == 'message' }
      end
    end

    it 'binding_stack should be empty after breaking out of the repl loop' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "exit-all"), StringIO.new) do
        ins = Pry.new.tap { |v| v.repl(0) }
      end

      ins.binding_stack.empty?.should == true
    end
  end

  describe "raise-up" do
    it "should raise the exception with raise-up" do
      redirect_pry_io(InputTester.new("raise NoMethodError", "raise-up NoMethodError"),StringIO.new) do
        lambda { Pry.new.repl(0) }.should.raise NoMethodError
      end
    end

    it "should raise an unamed exception with raise-up" do
      redirect_pry_io(InputTester.new("raise 'stop'","raise-up 'noreally'"),StringIO.new) do
        lambda { Pry.new.repl(0) }.should.raise RuntimeError, "noreally"
      end
    end

    it "should eat the exception at the last new pry instance on raise-up" do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("x.pry", "raise NoMethodError",
        "$inner = self", "raise-up NoMethodError", "$outer = self", "exit-all"),StringIO.new) do
        b.pry
      end
      $inner.should == :inner
      $outer.should == :outer
    end

    it "cd does not create a new instance, and raise-up doesn't respect the binding stack" do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")
      redirect_pry_io(InputTester.new("cd x", "raise NoMethodError","$inner = self",
        "deep = :deep", "cd deep","$deep = self","raise-up NoMethodError", "$outer = self", "exit-all"),StringIO.new) do
        lambda { b.pry }.should.raise NoMethodError
      end
      $deep.should == :deep
      $inner.should == :inner
      $outer.should == :outer
    end
  end

  describe "exit" do
    it 'should pop a binding with exit' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("cd x", "$inner = self;", "exit", "$outer = self", "exit-all"), StringIO.new) do
        b.pry
      end
      $inner.should == :inner
      $outer.should == :outer
    end

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with exit' do
      Pry.start(0, :input => StringIO.new("exit")).should == 0
    end

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with exit, and return user-given value' do
      Pry.start(0, :input => StringIO.new("exit :john")).should == :john
    end
  end

  describe "jump-to" do
    it 'should jump to the proper binding index in the stack' do
      outp = StringIO.new
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 1", "$blah = self", "exit-all"), outp) do
        Pry.start(0)
      end

      $blah.should == 1
    end

    it 'should print error when trying to jump to a non-existent binding index' do
      outp = StringIO.new
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 100", "exit-all"), outp) do
        Pry.start(0)
      end

      outp.string.should =~ /Invalid nest level/
    end

    it 'should print error when trying to jump to the same binding index' do
      outp = StringIO.new
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 2", "exit-all"), outp) do
        Pry.new.repl(0)
      end

      outp.string.should =~ /Already/
    end
  end

  describe "exit-program" do
    it 'should raise SystemExit' do
      redirect_pry_io(InputTester.new("exit-program"), StringIO.new) do
        lambda { Pry.new.repl(0).should == 0 }.should.raise SystemExit
      end
    end

    it 'should exit the program with the provided value' do
      redirect_pry_io(InputTester.new("exit-program 66"), StringIO.new) do
        begin
          Pry.new.repl(0)
        rescue SystemExit => e
          e.status.should == 66
        end
      end
    end
  end

  describe "cd" do
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

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with cd ..' do
      # redirect_pry_io(InputTester.new("ls"), StringIO.new) do
      #   o =  Pry.new.tap { |v| v.repl(0) }
      # end

      Pry.start(0, :input => StringIO.new("cd ..")).should == 0

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

    it 'should start a session on TOPLEVEL_BINDING with cd ::' do
      b = Pry.binding_for(:outer)

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
  end
end
