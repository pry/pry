require 'helper'

describe "Pry::Commands" do
  describe "help" do
    it 'should display help for a specific command' do
      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help ls", "exit-all"), str_output) do
        pry
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /ls --help/
    end

    it 'should display help for a regex command with a "listing"' do
      set = Pry::CommandSet.new do
        command /bar(.*)/, "Test listing", :listing => "foo" do
        end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help foo"), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /Test listing/
    end

    it 'should display help for a command with a spaces in its name' do
      set = Pry::CommandSet.new do
        command "command with spaces", "description of a command with spaces" do
        end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help \"command with spaces\""), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.each_line.count.should == 1
      str_output.string.should =~ /description of a command with spaces/
    end

    it 'should display help for all commands with a description' do
      set = Pry::CommandSet.new do
        command /bar(.*)/, "Test listing", :listing => "foo" do; end
        command "b", "description for b", :listing => "foo" do; end
        command "c" do;end
        command "d", "" do;end
      end

      str_output = StringIO.new
      redirect_pry_io(InputTester.new("help"), str_output) do
        Pry.new(:commands => set).rep
      end
      str_output.string.should =~ /Test listing/
      str_output.string.should =~ /description for b/
      str_output.string.should =~ /No description/
    end
  end
end
