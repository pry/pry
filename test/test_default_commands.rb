require 'helper'

describe "Pry::Commands" do

  after do
    $obj = nil
  end

  describe "hist" do
    before do
      Readline::HISTORY.clear
      @hist = Readline::HISTORY
    end

    it 'should display the correct history' do
      @hist.push "hello"
      @hist.push "world"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /hello\n.*world/
    end

    it 'should replay history correctly (single item)' do
      @hist.push "cd :hello"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0", "self", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /hello/
    end

    it 'should replay a range of history correctly (range of items)' do
      @hist.push ":hello"
      @hist.push ":carl"
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("hist --replay 0..1", "exit-all"), str_output) do
        pry
      end
      str_output.string.should =~ /:hello\n.*:carl/
    end

  end

  describe "show-method" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-method -l sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /def o.sample/
      $str_output = nil
    end

    it 'should output a method\'s source if inside method without needing to use method name, and using the -l switch' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-method -l", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /\d+: def o.sample/
      $str_output = nil
    end

  end

  describe "show-doc" do
    it 'should output a method\'s documentation' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-doc sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
        end
      end
      o.sample

      $str_output.string.should =~ /sample doc/
      $str_output = nil
    end
  end


  describe "cd" do
    it 'should cd into simple input' do
      b = Pry.binding_for(Object.new)
      b.eval("x = :mon_ouie")

      redirect_pry_io(InputTester.new("cd x", "$obj = self", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end

      $obj.should == :mon_ouie
    end

    it 'should break out of session with cd ..' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd ..", "$outer = self", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end
      $inner.should == :inner
      $outer.should == :outer
    end

    it 'should break out to outer-most session with cd /' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_pry_io(InputTester.new("cd x", "$inner = self;", "cd 5", "$five = self", "cd /", "$outer = self", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end
      $inner.should == :inner
      $five.should == 5
      $outer.should == :outer
    end

    it 'should start a session on TOPLEVEL_BINDING with cd ::' do
      b = Pry.binding_for(:outer)

      redirect_pry_io(InputTester.new("cd ::", "$obj = self", "exit-all"), StringIO.new) do
        Pry.new.repl(5)
      end
      $obj.should == TOPLEVEL_BINDING.eval('self')
    end

    it 'should cd into complex input (with spaces)' do
      o = Object.new
      def o.hello(x, y, z)
        :mon_ouie
      end

      redirect_pry_io(InputTester.new("cd hello 1, 2, 3", "$obj = self", "exit-all"), StringIO.new) do
        Pry.new.repl(o)
      end
      $obj.should == :mon_ouie
    end
  end
end
