require 'helper'

describe "'help' command" do
  before do
    @oldset = Pry.config.commands
    @set = Pry.config.commands = Pry::CommandSet.new do
      import Pry::DefaultCommands::Help
      import Pry::DefaultCommands::Ls
    end
  end

  after do
    Pry.config.commands = @oldset
  end

  it 'should display help for a specific command' do
    mock_pry('help ls').should =~ /Usage: ls/
  end

  it 'should display help for a regex command with a "listing"' do
    @set.command /bar(.*)/, "Test listing", :listing => "foo" do; end
    mock_pry('help foo').should =~ /Test listing/
  end

  it 'should display help for a command with a spaces in its name' do
    @set.command "command with spaces", "description of a command with spaces" do; end
    mock_pry('help "command with spaces"').should =~ /description of a command with spaces/
  end

  it 'should display help for all commands with a description' do
    @set.command /bar(.*)/, "Test listing", :listing => "foo" do; end
    @set.command "b", "description for b", :listing => "foo" do; end
    @set.command "c" do;end
    @set.command "d", "" do;end

    output = mock_pry('help')
    output.should =~ /Test listing/
    output.should =~ /description for b/
    output.should =~ /No description/
  end

  it "should sort the output of the 'help' command" do
    @set.command 'faa', "Fooerizes" do; end
    @set.command 'gaa', "Gooerizes" do; end
    @set.command 'maa', "Mooerizes" do; end
    @set.command 'baa', "Booerizes" do; end

    doc = mock_pry('help')

    order = [doc.index("baa"),
             doc.index("faa"),
             doc.index("gaa"),
             doc.index("maa")]

    order.should == order.sort
  end
end
