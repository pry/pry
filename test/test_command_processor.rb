require 'helper'

describe "Pry::CommandProcessor" do

  before do
    @pry = Pry.new
    @pry.commands = Pry::CommandSet.new
    @command_processor = Pry::CommandProcessor.new(@pry)
  end

  after do
    @pry.commands = Pry::CommandSet.new
  end

  it 'should correctly match a simple string command' do
    @pry.commands.command("test-command") {}
    command, captures, pos = @command_processor.command_matched "test-command"

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should correctly match a simple string command with parameters' do
    @pry.commands.command("test-command") { |arg|}
    command, captures, pos = @command_processor.command_matched "test-command hello"

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should not match when the relevant command does not exist' do
    command, captures, pos = @command_processor.command_matched "test-command"

    command.should == nil
    captures.should == nil
  end

  it 'should correctly match a regex command' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue hello"

    command.name.should == /rue(.?)/
    captures.should == [""]
    pos.should == 3
  end

  it 'should correctly match a regex command and extract the capture groups' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue5 hello"

    command.name.should == /rue(.?)/
    captures.should == ["5"]
    pos.should == 4
  end

  it 'should correctly match a string command with spaces in its name' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command"

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a string command with spaces in its name with parameters' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command param1 param2"

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a regex command with spaces in its name' do
    regex_command_name = /test\s+(.+)\s+command/
    @pry.commands.command(regex_command_name) {}

    sample_text = "test friendship command"
    command, captures, pos = @command_processor.command_matched sample_text

    command.name.should == regex_command_name
    captures.should == ["friendship"]
    pos.should == sample_text.size
  end

  it 'should correctly match a complex regex command' do
    regex_command_name = /\.(.*)/
    @pry.commands.command(regex_command_name) {}

    sample_text = ".cd ~/pry"
    command, captures, pos = @command_processor.command_matched sample_text

    command.name.should == regex_command_name
    captures.should == ["cd ~/pry"]
    pos.should == sample_text.size
  end
end
