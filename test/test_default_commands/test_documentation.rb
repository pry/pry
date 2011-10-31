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

      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
       end
      end
      o.sample
      $str_output.string.should =~ /This is a test comment/
      $str_output = nil
    end

    it 'should output a method\'s documentation as plain text if Pry.color is false' do
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
      # @note This is a interweaved note
      # @example Description
      #   {'seven': 'value'}
      #   {'eight': 'value'}
      # @see https://github.com/pry/pry

      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
       end
      end
      o.sample

      test_string = $str_output.string.split("\n").compact.delete_if { |value| value.empty? }
      $str_output = nil
      test_string[0].should =~ /From: test\/test_default_commands\/test_documentation\.rb @ line/
      test_string[1].should =~ /Number of lines/
      test_string[2].should =~ /Owner: #<Class:#<Object:[^>]+>>/
      test_string[3].should == 'Visibility: public'
      test_string[4].should == 'Signature: sample()'
      test_string[5].should == 'This is a test comment'
      test_string[6].should == '  This is a test comment'
      test_string[7].should == 'The Test method {\'one\': \'value\'}'
      test_string[8].should == '{\'two\': \'value\'}'
      test_string[9].should == '`{\'three\': \'value\'}`'
      test_string[10].should == 'note A message'
      test_string[11].should == 'example `{\'four\': \'value\'}`'
      test_string[12].should == 'example {\'five\': \'value\'}'
      test_string[13].should == 'example'
      test_string[14].should == '  `{\'six\': \'value\'}`'
      test_string[15].should == 'note This is a interweaved note'
      test_string[16].should == 'example Description'
      test_string[17].should == '  {\'seven\': \'value\'}'
      test_string[18].should == '  {\'eight\': \'value\'}'
      test_string[19].should == 'see https://github.com/pry/pry'
    end

    it 'should output a method\'s documentation with ANSI colors if Pry.color is true' do
      Pry.color = true
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
      # @note This is a interweaved note
      # @example Description
      #   {'seven': 'value'}
      #   {'eight': 'value'}
      # @see https://github.com/pry/pry

      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
       end
      end
      o.sample

      Pry.color = false
      test_string = $str_output.string.split("\n").compact.delete_if { |value| value.empty? }
      $str_output = nil
      test_string[0].should =~ /\e\[1mFrom:\e\[0m test\/test_default_commands\/test_documentation.rb @ line/
      test_string[1].should =~ /\e\[1mNumber of lines:\e\[0m/
      test_string[2].should =~ /\e\[1mOwner:\e\[0m #<Class:#<Object:[^>]+>>/
      test_string[3].should =~ /\e\[1mVisibility:\e\[0m public/
      test_string[4].should =~ /\e\[1mSignature:\e\[0m sample()/
      test_string[5].should == 'This is a test comment'
      test_string[6].should == '  This is a test comment'
      test_string[7].should == "The Test method {\e[32m\e[1;32m'\e[0m\e[32mone\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}"
      test_string[8].should == "{\e[32m\e[1;32m'\e[0m\e[32mtwo\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}"
      test_string[9].should == "\e[0;33m`\e[0m{\e[32m\e[1;32m'\e[0m\e[32mthree\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}\e[0;33m`\e[0m"
      test_string[10].should == "\e[33mnote\e[0m A message"
      test_string[11].should == "\e[0;33mexample\e[0m \e[0;33m`\e[0m{'four': 'value'}\e[0;33m`\e[0m"
      test_string[12].should == "\e[0;33mexample\e[0m {'five': 'value'}"
      test_string[13].should == "\e[0;33mexample\e[0m"
      test_string[14].should == "  \e[0;33m`\e[0m{\e[32m\e[1;32m'\e[0m\e[32msix\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}\e[0;33m`\e[0m"
      test_string[15].should == "\e[33mnote\e[0m This is a interweaved note"
      test_string[16].should == "\e[0;33mexample\e[0m Description"
      test_string[17].should == "  {\e[32m\e[1;32m'\e[0m\e[32mseven\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}"
      test_string[18].should == "  {\e[32m\e[1;32m'\e[0m\e[32meight\e[1;32m'\e[0m\e[32m\e[0m: \e[32m\e[1;32m'\e[0m\e[32mvalue\e[1;32m'\e[0m\e[32m\e[0m}"
      test_string[19].should == "\e[33msee\e[0m https://github.com/pry/pry"
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
