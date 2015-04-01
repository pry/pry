require_relative 'helper'

describe "Pry.run_command" do
  before(:all) do
    command_proc = proc do
      def process
        args.first
      end
    end

    Pry.commands.instance_eval do
      create_command("command-with-return-value", { :keep_retval => true }, &command_proc)
      create_command("command-without-return-value", &command_proc)
    end
  end

  before do
    o = Object.new
    def o.drum
      "roken is dodelijk"
    end
    @context = Pry.binding_for(o)
  end

  it 'performs a simple ls' do
    @context.eval("hokey_pokey = 10")
    Pry.run_command "ls", :context => @context, :output => out = StringIO.new
    expect(out.string).to match(/hokey_pokey/)
  end

  # This is a regression test as 0.9.11 broke this behaviour
  it 'can perform a show-source' do
    Pry.run_command "show-source drum", :context => @context, :output => out = StringIO.new
    expect(out.string).to match(/roken is dodelijk/)
  end

  context "return value" do
    it "returns the return value of a command that keeps its return value" do
      expected_value = "command_result"
      result = Pry.run_command("command-with-return-value #{expected_value}", :show_output => false)
      expect(result).to eq(expected_value)
    end

    it "returns nil for a command that does not keep its return value" do
      result = Pry.run_command("command-without-return-value unexpected_value", :show_output => false)
      expect(result).to be_nil
    end
  end
end
