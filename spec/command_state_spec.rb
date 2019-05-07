# frozen_string_literal: true

RSpec.describe Pry::CommandState do
  describe ".default" do
    it "returns the default command state" do
      expect(described_class.default).to be_a(described_class)
    end

    context "when called multiple times" do
      it "returns the same command state" do
        first_state = described_class.default
        second_state = described_class.default
        expect(first_state).to eql(second_state)
      end
    end
  end

  describe "#state_for" do
    it "returns a state for the matching command" do
      subject.state_for('command').foobar = 1
      expect(subject.state_for('command').foobar).to eq(1)
    end

    it "returns new state for new command" do
      expect(subject.state_for('command'))
        .not_to equal(subject.state_for('other-command'))
    end

    it "memoizes state for the same command" do
      expect(subject.state_for('command')).to equal(subject.state_for('command'))
    end
  end

  describe "#reset" do
    it "resets the command state for the given command" do
      subject.state_for('command').foobar = 1
      subject.reset('command')
      expect(subject.state_for('command').foobar).to be_nil
    end

    it "doesn't reset command state for other commands" do
      subject.state_for('command').foobar = 1
      subject.state_for('other-command').foobar = 1
      subject.reset('command')

      expect(subject.state_for('other-command').foobar).to eq(1)
    end
  end
end
