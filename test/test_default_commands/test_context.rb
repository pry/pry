require 'helper'

describe "Pry::DefaultCommands::Context" do
  describe "quit" do
    it 'should break out of the repl loop of Pry instance (returning target of session)' do
      redirect_pry_io(InputTester.new("quit"), StringIO.new) do
        Pry.new.repl(0).should == 0
      end
    end

    it 'should break out of the repl loop of Pry instance wth a user specified value' do
      redirect_pry_io(InputTester.new("quit 'message'"), StringIO.new) do
        Pry.new.repl(0).should == 'message'
      end
    end

    it 'should quit break of the repl loop even if multiple bindings still on stack' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "quit 'message'"), StringIO.new) do
        ins = Pry.new.tap { |v| v.repl(0).should == 'message' }
      end
    end

    it 'binding_stack should be empty after breaking out of the repl loop' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "quit 'message'"), StringIO.new) do
        ins = Pry.new.tap { |v| v.repl(0) }
      end

      ins.binding_stack.empty?.should == true
    end

  end

  describe "exit" do
    it 'should raise SystemExit' do
      redirect_pry_io(InputTester.new("exit"), StringIO.new) do
        lambda { Pry.new.repl(0).should == 0 }.should.raise SystemExit
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

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding' do
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
