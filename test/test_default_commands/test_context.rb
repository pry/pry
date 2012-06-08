require 'helper'

describe "Pry::DefaultCommands::Context" do
  describe "exit-all" do
    it 'should break out of the repl loop of Pry instance and return nil' do
      redirect_pry_io(InputTester.new("exit-all"), StringIO.new) do
        Pry.new.repl(0).should == nil
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

  describe "whereami" do
    it 'should work with methods that have been undefined' do
      class Cor
        def blimey!
          Cor.send :undef_method, :blimey!
          # using [.] so the regex doesn't match itself
          mock_pry(binding, 'whereami').should =~ /self[.]blimey!/
        end
      end

      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should work in objects with no method methods' do
      class Cor
        def blimey!
          mock_pry(binding, 'whereami').should =~ /Cor[#]blimey!/
        end

        def method; "moo"; end
      end
      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should properly set _file_, _line_ and _dir_' do
      class Cor
        def blimey!
          mock_pry(binding, 'whereami', '_file_') \
            .should =~ /#{File.expand_path(__FILE__)}/
        end
      end

      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should show description and correct code when __LINE__ and __FILE__ are outside @method.source_location' do
      class Cor
        def blimey!
          eval <<-END, binding, "test/test_default_commands/example.erb", 1
            mock_pry(binding, 'whereami')
          END
        end
      end

      Cor.instance_method(:blimey!).source.should =~ /mock_pry/

      Cor.new.blimey!.should =~ /Cor#blimey!.*Look at me/m
      Object.remove_const(:Cor)
    end

    it 'should show description and correct code when @method.source_location would raise an error' do
      class Cor
        eval <<-END, binding, "test/test_default_commands/example.erb", 1
          def blimey!
            mock_pry(binding, 'whereami')
          end
        END
      end

      lambda{
        Cor.instance_method(:blimey!).source
      }.should.raise(MethodSource::SourceNotFoundError)

      Cor.new.blimey!.should =~ /Cor#blimey!.*Look at me/m
      Object.remove_const(:Cor)

    end

    it 'should display a description and and error if reading the file goes wrong' do
      class Cor
        def blimey!
          eval <<-END, binding, "not.found.file.erb", 7
            mock_pry(binding, 'whereami')
          END
        end
      end

      Cor.new.blimey!.should =~ /From: not.found.file.erb @ line 7 Cor#blimey!:\n\nError: Cannot open "not.found.file.erb" for reading./m
      Object.remove_const(:Cor)
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
      Pry.start(0, :input => StringIO.new("exit")).should == nil
    end

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with exit, and return user-given value' do
      Pry.start(0, :input => StringIO.new("exit :john")).should == :john
    end

    it 'should break out the repl loop of Pry instance even after an exception in user-given value' do
      redirect_pry_io(InputTester.new("exit = 42", "exit"), StringIO.new) do
        ins = Pry.new.tap { |v| v.repl(0).should == nil }
      end
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

    it "should raise the most recently raised exception" do
      lambda { mock_pry("raise NameError, 'homographery'","raise-up") }.should.raise NameError, 'homographery'
    end

    it "should allow you to cd up and (eventually) out" do
      $deep = $inner = $outer = nil
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")
      redirect_pry_io(InputTester.new("cd x", "raise NoMethodError","$inner = self",
        "deep = :deep", "cd deep","$deep = self","raise-up NoMethodError", "raise-up", "$outer = self", "raise-up", "exit-all"),StringIO.new) do
        lambda { b.pry }.should.raise NoMethodError
      end
      $deep.should == :deep
      $inner.should == :inner
      $outer.should == :outer
    end
  end

  describe "raise-up!" do
    it "should jump immediately out of nested context's" do
      lambda { mock_pry("cd 1", "cd 2", "cd 3", "raise-up! 'fancy that...'") }.should.raise RuntimeError, 'fancy that...'
    end
  end

  describe "skip" do
    it 'should skip next session' do
      mock_pry('$skipped = true', 'skip')

      mock_pry('$skipped = false', 'skip')
      $skipped.should == true

      mock_pry('$skipped = false', 'exit-all')
      $skipped.should == false
    end

    it 'should skip next sessions' do
      mock_pry('$skipped = true', 'skip 2')

      mock_pry('$skipped = false', 'exit-all')
      $skipped.should == true

      mock_pry('$skipped = false', 'exit-all')
      $skipped.should == true
    end

    it 'should break out of the repl loop of Pry instance' do
      $break = true
      mock_pry('skip', '$break = false')
      $break.should == true
    end
  end
end
