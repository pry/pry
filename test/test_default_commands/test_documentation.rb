require 'helper'

describe "Pry::DefaultCommands::Documentation" do
  describe "show-doc" do
    it 'should output a method\'s documentation' do
      redirect_pry_io(InputTester.new("show-doc sample_method", "exit-all"), str_output=StringIO.new) do
        pry
      end

      str_output.string.should =~ /sample doc/
    end

    it 'should output a method\'s documentation with line numbers' do
      redirect_pry_io(InputTester.new("show-doc sample_method -l", "exit-all"), str_output=StringIO.new) do
        pry
      end

      str_output.string.should =~ /\d: sample doc/
    end

    it 'should output a method\'s documentation with line numbers (base one)' do
      redirect_pry_io(InputTester.new("show-doc sample_method -b", "exit-all"), str_output=StringIO.new) do
        pry
      end

      str_output.string.should =~ /1: sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      o = Object.new

      # sample comment
      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $out=StringIO.new) do
          binding.pry
       end
      end
      o.sample
      $out.string.should =~ /sample comment/
      $out = nil
    end

    it "should be able to find super methods" do

      c = Class.new{
        # classy initialize!
        def initialize(*args); end
      }

      d = Class.new(c){
        # grungy initialize??
        def initialize(*args, &block); end
      }

      o = d.new

      # instancey initialize!
      def o.initialize; end

      mock_pry(binding, "show-doc o.initialize").should =~ /instancey initialize/
      mock_pry(binding, "show-doc --super o.initialize").should =~ /grungy initialize/
      mock_pry(binding, "show-doc o.initialize -ss").should =~ /classy initialize/
      mock_pry(binding, "show-doc --super o.initialize -ss").should == mock_pry("show-doc Object#initialize")
    end
  end
end
