require 'helper'

describe "Pry::DefaultCommands::Context" do

  before do
    @self  = "Pad.self = self"
    @inner = "Pad.inner = self"
    @outer = "Pad.outer = self"
  end

  after do
    Pad.clear
  end

  describe "exit-all" do
    it 'should break out of the repl loop of Pry instance and return nil' do
      redirect_pry_io(InputTester.new("exit-all")) do
        Pry.new.repl(0).should == nil
      end
    end

    it 'should break out of the repl loop of Pry instance wth a user specified value' do
      redirect_pry_io(InputTester.new("exit-all 'message'")) do
        Pry.new.repl(0).should == 'message'
      end
    end

    it 'should break of the repl loop even if multiple bindings still on stack' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "exit-all 'message'")) do
        ins = Pry.new.tap { |v| v.repl(0).should == 'message' }
      end
    end

    it 'binding_stack should be empty after breaking out of the repl loop' do
      ins = nil
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "exit-all")) do
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

    it 'should show code window (not just method source) if parameter passed to whereami' do
      class Cor
        def blimey!
          mock_pry(binding, 'whereami 3').should =~ /class Cor/
        end
      end
      Cor.new.blimey!
      Object.remove_const(:Cor)
    end

    it 'should use Pry.config.default_window_size for window size when outside a method context' do
      old_size, Pry.config.default_window_size = Pry.config.default_window_size, 1
      :litella
      :pig
      out = mock_pry(binding, 'whereami')
      :punk
      :sanders

      out.should.not =~ /:litella/
      out.should =~ /:pig/
      out.should =~ /:punk/
      out.should.not =~ /:sanders/

      Pry.config.default_window_size = old_size
    end

    it "should work at the top level" do
      mock_pry(Pry.toplevel_binding, 'whereami').should =~ /At the top level/
    end

    it "should work inside a class" do
      mock_pry(Pry.binding_for(Pry), 'whereami').should =~ /Inside Pry/
    end

    it "should work inside an object" do
      mock_pry(Pry.binding_for(Object.new), 'whereami').should =~ /Inside #<Object/
    end
  end

  describe "exit" do
    it 'should pop a binding with exit' do
      redirect_pry_io(InputTester.new("cd :inner", @inner, "exit",
                                       @outer, "exit-all")) do
        Pry.start(:outer)
      end

      Pad.inner.should == :inner
      Pad.outer.should == :outer
    end

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with exit' do
      Pry.start(0, :input => StringIO.new("exit")).should == nil
    end

    it 'should break out of the repl loop of Pry instance when binding_stack has only one binding with exit, and return user-given value' do
      Pry.start(0, :input => StringIO.new("exit :john")).should == :john
    end

    it 'should break out the repl loop of Pry instance even after an exception in user-given value' do
      redirect_pry_io(InputTester.new("exit = 42", "exit")) do
        ins = Pry.new.tap { |v| v.repl(0).should == nil }
      end
    end
  end

  describe "jump-to" do
    before do
      @str_output = StringIO.new
    end

    it 'should jump to the proper binding index in the stack' do
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 1", @self, "exit-all")) do
        Pry.start(0)
      end

      Pad.self.should == 1
    end

    it 'should print error when trying to jump to a non-existent binding index' do
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 100", "exit-all"), @str_output) do
        Pry.start(0)
      end

      @str_output.string.should =~ /Invalid nest level/
    end

    it 'should print error when trying to jump to the same binding index' do
      redirect_pry_io(InputTester.new("cd 1", "cd 2", "jump-to 2", "exit-all"), @str_output) do
        Pry.new.repl(0)
      end

      @str_output.string.should =~ /Already/
    end
  end

  describe "exit-program" do
    it 'should raise SystemExit' do
      redirect_pry_io(InputTester.new("exit-program")) do
        lambda { Pry.new.repl(0).should == 0 }.should.raise SystemExit
      end
    end

    it 'should exit the program with the provided value' do
      redirect_pry_io(InputTester.new("exit-program 66")) do
        begin
          Pry.new.repl(0)
        rescue SystemExit => e
          e.status.should == 66
        end
      end
    end
  end

  describe "raise-up" do
    it "should raise the exception with raise-up" do
      redirect_pry_io(InputTester.new("raise NoMethodError", "raise-up NoMethodError")) do
        lambda { Pry.new.repl(0) }.should.raise NoMethodError
      end
    end

    it "should raise an unamed exception with raise-up" do
      redirect_pry_io(InputTester.new("raise 'stop'","raise-up 'noreally'")) do
        lambda { Pry.new.repl(0) }.should.raise RuntimeError, "noreally"
      end
    end

    it "should eat the exception at the last new pry instance on raise-up" do
      redirect_pry_io(InputTester.new(":inner.pry", "raise NoMethodError", @inner,
                                      "raise-up NoMethodError", @outer, "exit-all")) do
        Pry.start(:outer)
      end

      Pad.inner.should == :inner
      Pad.outer.should == :outer
    end

    it "should raise the most recently raised exception" do
      lambda { mock_pry("raise NameError, 'homographery'","raise-up") }.should.raise NameError, 'homographery'
    end

    it "should allow you to cd up and (eventually) out" do
      redirect_pry_io(InputTester.new("cd :inner", "raise NoMethodError", @inner,
                                      "deep = :deep", "cd deep","Pad.deep = self",
                                      "raise-up NoMethodError", "raise-up", @outer,
                                      "raise-up", "exit-all")) do
        lambda { Pry.start(:outer) }.should.raise NoMethodError
      end

      Pad.deep.should  == :deep
      Pad.inner.should == :inner
      Pad.outer.should == :outer
    end
  end

  describe "raise-up!" do
    it "should jump immediately out of nested context's" do
      lambda { mock_pry("cd 1", "cd 2", "cd 3", "raise-up! 'fancy that...'") }.should.raise RuntimeError, 'fancy that...'
    end
  end
end
