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
        Dir.stubs(:chdir)
      end

      it "saves the current working directory" do
        Dir.stubs(:pwd).returns("initial_path")

        @t.eval ".cd new_path"
        @t.command_state.old_pwd.should == "initial_path"
      end

      describe "given a path" do
        it "sends the path to File.expand_path" do
          Dir.expects(:chdir).with(File.expand_path("new_path"))
          @t.eval ".cd new_path"
        end
      end

      describe "given an empty string" do
        it "sends ~ to File.expand_path" do
          Dir.expects(:chdir).with(File.expand_path("~"))
          @t.eval ".cd "
        end
      end

      describe "given a dash" do
        describe "given no prior directory" do
          it "raises the correct error" do
            lambda { @t.eval ".cd -" }.should.raise(StandardError).
              message.should == "No prior directory available"
          end
        end

        describe "given a prior directory" do
          it "sends the user's last pry working directory to File.expand_path" do
            Dir.stubs(:pwd).returns("initial_path")

            Dir.expects(:chdir).with(File.expand_path("new_path"))
            @t.eval ".cd new_path"

            Dir.expects(:chdir).with(File.expand_path("initial_path"))
            @t.eval ".cd -"
          end
        end
      end
    end
  end
end
