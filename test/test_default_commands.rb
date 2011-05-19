require 'helper'

describe "Pry::Commands" do

  describe "show-method" do
    it 'should output a method\'s source' do
      str_output = StringIO.new
      redirect_global_pry_input_output(InputTester.new("show-method sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /def sample/
    end

    it 'should output a method\'s source with line numbers' do
      str_output = StringIO.new
      redirect_global_pry_input_output(InputTester.new("show-method -l sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /\d+: def sample/
    end

    it 'should output a method\'s source if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_global_pry_input_output(InputTester.new("show-method", "exit-all"), $str_output) do
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
        redirect_global_pry_input_output(InputTester.new("show-method -l", "exit-all"), $str_output) do
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
      redirect_global_pry_input_output(InputTester.new("show-doc sample_method", "exit-all"), str_output) do
        Pry.new.repl(TOPLEVEL_BINDING)
      end

      str_output.string.should =~ /sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new
      def o.sample
        redirect_global_pry_input_output(InputTester.new("show-doc", "exit-all"), $str_output) do
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

      redirect_global_pry_input_output(InputTester.new("cd x", "self.should == :mon_ouie;", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end
    end

    it 'should break out of session with cd ..' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_global_pry_input_output(InputTester.new("cd x", "self.should == :inner;", "cd ..", "self.should == :outer", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end
    end

    it 'should break out to outer-most session with cd /' do
      b = Pry.binding_for(:outer)
      b.eval("x = :inner")

      redirect_global_pry_input_output(InputTester.new("cd x", "self.should == :inner;", "cd 5", "self.should == 5", "cd /", "self.should == :outer", "exit-all"), StringIO.new) do
        Pry.new.repl(b)
      end
    end

    it 'should start a session on TOPLEVEL_BINDING with cd ::' do
      b = Pry.binding_for(:outer)

      redirect_global_pry_input_output(InputTester.new("cd ::", "self.should == TOPLEVEL_BINDING.eval('self')", "exit-all"), StringIO.new) do
        Pry.new.repl(5)
      end
    end

    it 'should cd into complex input (with spaces)' do
      o = Object.new
      def o.hello(x, y, z)
        :mon_ouie
      end

      redirect_global_pry_input_output(InputTester.new("cd hello 1, 2, 3", "self.should == :mon_ouie", "exit-all"), StringIO.new) do
        Pry.new.repl(o)
      end
    end
  end
end
