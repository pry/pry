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

      # sample comment
      def o.sample
        redirect_pry_io(InputTester.new("show-doc", "exit-all"), $str_output) do
          binding.pry
       end
      end
      o.sample

      $str_output.string.should =~ /sample comment/
      $str_output = nil
    end
  end
end
