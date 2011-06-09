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

  it 'should accurately determine if a command is valid' do
    @pry.commands.command("test-command") {}
    valid = @command_processor.valid_command? "test-command"
    valid.should == true

    valid = @command_processor.valid_command? "blah"
    valid.should == false


    a = "test-command"

    # not passing in a binding so 'a' shoudn't exist and should cause error
    lambda { @command_processor.valid_command? '#{a}' }.should.raise NameError

    # passing in the optional binding (against which interpolation is performed)
    valid = @command_processor.valid_command? '#{a}', binding
    valid.should == true
  end

  it 'should correctly match a simple string command' do
    @pry.commands.command("test-command") {}
    command, captures, pos = @command_processor.command_matched "test-command", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should correctly match a simple string command with parameters' do
    @pry.commands.command("test-command") { |arg|}
    command, captures, pos = @command_processor.command_matched "test-command hello", binding

    command.name.should == "test-command"
    captures.should == []
    pos.should == "test-command".length
  end

  it 'should not match when the relevant command does not exist' do
    command, captures, pos = @command_processor.command_matched "test-command", binding

    command.should == nil
    captures.should == nil
  end

  it 'should correctly match a regex command' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue hello", binding

    command.name.should == /rue(.?)/
    captures.should == [""]
    pos.should == 3
  end

  it 'should correctly match a regex command and extract the capture groups' do
    @pry.commands.command(/rue(.?)/) { }
    command, captures, pos = @command_processor.command_matched "rue5 hello", binding

    command.name.should == /rue(.?)/
    captures.should == ["5"]
    pos.should == 4
  end

  it 'should correctly match a string command with spaces in its name' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command", binding

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a string command with spaces in its name with parameters' do
    @pry.commands.command("test command") {}
    command, captures, pos = @command_processor.command_matched "test command param1 param2", binding

    command.name.should == "test command"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a regex command with spaces in its name' do
    regex_command_name = /test\s+(.+)\s+command/
    @pry.commands.command(regex_command_name) {}

    sample_text = "test friendship command"
    command, captures, pos = @command_processor.command_matched sample_text, binding

    command.name.should == regex_command_name
    captures.should == ["friendship"]
    pos.should == sample_text.size
  end

  it 'should correctly match a complex regex command' do
    regex_command_name = /\.(.*)/
    @pry.commands.command(regex_command_name) {}

    sample_text = ".cd ~/pry"
    command, captures, pos = @command_processor.command_matched sample_text, binding

    command.name.should == regex_command_name
    captures.should == ["cd ~/pry"]
    pos.should == sample_text.size
  end

  it 'should correctly match a command whose name is interpolated' do
    @pry.commands.command("blah") {}
    a = "bl"
    b = "ah"
    command, captures, pos = @command_processor.command_matched '#{a}#{b}', binding

    command.name.should == "blah"
    captures.should == []
    pos.should == command.name.length
  end

  it 'should correctly match a regex command and interpolation should not break the regex' do
    regex_command_name = /blah(\d)/
    @pry.commands.command(regex_command_name) {}

    sample_text = "blah5"
    a = "5"
    command, captures, pos = @command_processor.command_matched 'blah#{a}', binding

    command.name.should == regex_command_name
    captures.should == ["5"]
    pos.should == sample_text.size
  end

  it 'should NOT match a regex command that is interpolated when :interpolate => false' do
    regex_command_name = /blah(\d)/
    @pry.commands.command(regex_command_name, "", :interpolate => false) {}

    sample_text = "blah5"
    a = "5"
    command, captures, pos = @command_processor.command_matched 'blah#{a}', binding

    command.should == nil
  end

  it 'should correctly match a regex command and interpolation should not break the regex where entire regex command is interpolated' do
    regex_command_name = /blah(\d)/
    @pry.commands.command(regex_command_name) {}

    sample_text = "blah5"
    a = "bl"
    b = "ah"
    c = "5"

    command, captures, pos = @command_processor.command_matched '#{a}#{b}#{c}', binding

    command.name.should == regex_command_name
    captures.should == ["5"]
    pos.should == sample_text.size
  end

  it 'should NOT match a regex command where entire regex command is interpolated and :interpolate => false' do
    regex_command_name = /blah(\d)/
    @pry.commands.command(regex_command_name, "", :interpolate => false) {}

    sample_text = "blah5"
    a = "bl"
    b = "ah"
    c = "5"

    command, captures, pos = @command_processor.command_matched '#{a}#{b}#{c}', binding
    command.should == nil
  end

  it 'should NOT match a command whose name is interpolated when :interpolate => false' do
    @pry.commands.command("boast", "", :interpolate => false) {}
    a = "boa"
    b = "st"

    # remember to use '' instead of "" when testing interpolation or
    # you'll cause yourself incredible confusion
    command, captures, pos = @command_processor.command_matched '#{a}#{b}', binding

    command.should == nil
  end
end
