require 'helper'

describe "help" do
  before do
    @oldset = Pry.config.commands
    @set = Pry.config.commands = Pry::CommandSet.new do
      import Pry::Commands
    end
  end

  after do
    Pry.config.commands = @oldset
  end

  it 'should display help for a specific command' do
    pry_eval('help ls').should =~ /Usage: ls/
  end

  it 'should display help for a regex command with a "listing"' do
    @set.command /bar(.*)/, "Test listing", :listing => "foo" do; end
    pry_eval('help foo').should =~ /Test listing/
  end

  it 'should display help for a command with a spaces in its name' do
    @set.command "cmd with spaces", "desc of a cmd with spaces" do; end
    pry_eval('help "cmd with spaces"').should =~ /desc of a cmd with spaces/
  end

  it 'should display help for all commands with a description' do
    @set.command /bar(.*)/, "Test listing", :listing => "foo" do; end
    @set.command "b", "description for b", :listing => "foo" do; end
    @set.command "c" do;end
    @set.command "d", "" do;end

    output = pry_eval('help')
    output.should =~ /Test listing/
    output.should =~ /description for b/
    output.should =~ /No description/
  end

  it "should sort the output of the 'help' command" do
    @set.command 'faa', "Fooerizes" do; end
    @set.command 'gaa', "Gooerizes" do; end
    @set.command 'maa', "Mooerizes" do; end
    @set.command 'baa', "Booerizes" do; end

    doc = pry_eval('help')

    order = [doc.index("baa"),
             doc.index("faa"),
             doc.index("gaa"),
             doc.index("maa")]

    order.should == order.sort
  end
end
