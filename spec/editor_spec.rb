require 'helper'
describe Pry::Editor do
  describe "build_editor_invocation_string" do
      before do
        class << Pry::Editor
            public :build_editor_invocation_string
        end
      end

      it 'should shell-escape files' do
        Pry::Editor.build_editor_invocation_string("/tmp/hello world.rb", 5, true).should =~ %r(/tmp/hello\\ world.rb)
      end
  end

  describe "build_editor_invocation_string on windows" do
      before do
        class << Pry::Editor
            def windows?; true; end
        end
      end

      after do
        class << Pry::Editor
            undef windows?
        end
      end

      it "should replace / by \\" do
        Pry::Editor.build_editor_invocation_string("/tmp/hello world.rb", 5, true).should =~ %r(\\tmp\\)
      end

      it "should not shell-escape files" do
        Pry::Editor.build_editor_invocation_string("/tmp/hello world.rb", 5, true).should =~ %r(hello world.rb)
      end
  end

  describe 'invoke_editor with a proc' do
      before do
        @old_editor = Pry.config.editor
      Pry.config.editor = proc{ |file, line, blocking|
          @file = file
          nil
      }
      end

      after do
        Pry.config.editor = @old_editor
      end

      it 'should not shell-escape files' do
        Pry::Editor.invoke_editor('/tmp/hello world.rb', 10, true)
        @file.should == "/tmp/hello world.rb"
      end
  end
end
