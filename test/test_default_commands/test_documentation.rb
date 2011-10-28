require 'helper'

describe "Pry::DefaultCommands::Documentation" do
  describe "show-doc" do
    it 'should output a method\'s documentation' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("show-doc sample_method", "exit-all"), str_output) do
        pry
      end

      str_output.string.should =~ /sample doc/
    end

    it 'should output a method\'s documentation if inside method without needing to use method name' do
      $str_output = StringIO.new

      o = Object.new

      # This is a test comment
      #   This is a test comment
      # The Test method `{'one': 'value'}`
      # <code>{'two': 'value'}</code>
      # <code>`{'three': 'value'}`</code>
      # @note A message
      # @example `{'four': 'value'}`
      # @example {'five': 'value'}
      # @example
      #   `{'six': 'value'}`
      # @example
      #   {'seven': 'value'}
      #   {'eight': 'value'}
      # @see https://github.com/pry/pry
      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
       end
      end
      o.sample

      $str_output.string.should =~ /This is a test comment/
      $str_output.string.should =~ /  This is a test comment/
      $str_output.string.should =~ /The Test method {'one': 'value'}/
      $str_output.string.should =~ /{'two': 'value'}/
      $str_output.string.should =~ /`{'three': 'value'}`/
      $str_output.string.should =~ /note A message/
      $str_output.string.should =~ /example `{'four': 'value'}`/
      $str_output.string.should =~ /example {'five': 'value'}/
      $str_output.string.should =~ /example\n  `{'six': 'value'}`/
      $str_output.string.should =~ /example\n  {'seven': 'value'}\n  {'eight': 'value'}/
      $str_output.string.should =~ /see https:\/\/github.com\/pry\/pry/
      $str_output = nil
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

