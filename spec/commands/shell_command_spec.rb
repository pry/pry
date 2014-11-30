require_relative '../helper'

describe "Command::ShellCommand" do
  describe 'cd' do
    before do
      @o = Object.new

      @t = pry_tester(@o) do
        def command_state
          pry.command_state[Pry::Command::ShellCommand.match]
        end
      end
    end

    describe ".cd" do
      before do
        allow(Dir).to receive(:chdir)
      end

      it "saves the current working directory" do
        expect(Dir).to receive(:pwd).at_least(:once).and_return("initial_path") # called once in MRI, 2x in RBX

        @t.eval ".cd new_path"
        expect(@t.command_state.old_pwd).to eq("initial_path")
      end

      describe "given a path" do
        it "sends the path to File.expand_path" do
          expect(Dir).to receive(:chdir).with(File.expand_path("new_path"))
          @t.eval ".cd new_path"
        end
      end

      describe "given an empty string" do
        it "sends ~ to File.expand_path" do
          expect(Dir).to receive(:chdir).with(File.expand_path("~"))
          @t.eval ".cd "
        end
      end

      describe "given a dash" do
        describe "given no prior directory" do
          it "raises the correct error" do
            expect { @t.eval ".cd -" }.to raise_error(StandardError, "No prior directory available")
          end
        end

        describe "given a prior directory" do
          it "sends the user's last pry working directory to File.expand_path" do
            expect(Dir).to receive(:pwd).at_least(:twice).and_return("initial_path") # called 2x in MRI, 3x in RBX

            expect(Dir).to receive(:chdir).with(File.expand_path("new_path"))
            @t.eval ".cd new_path"

            expect(Dir).to receive(:chdir).with(File.expand_path("initial_path"))
            @t.eval ".cd -"
          end
        end
      end
    end
  end
end
