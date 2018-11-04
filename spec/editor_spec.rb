require 'pathname'
require_relative 'helper'

describe Pry::Editor do
  class Pry::Editor
    public :build_editor_invocation_string
  end

  before do
    # OS-specific tempdir name. For GNU/Linux it's "tmp", for Windows it's
    # something "Temp".
    @tf_dir =
      if Pry::Helpers::Platform.mri_19?
        Pathname.new(Dir::Tmpname.tmpdir)
      else
        Pathname.new(Dir.tmpdir)
      end

    @tf_path = File.join(@tf_dir.to_s, 'hello world.rb')

    @editor = Pry::Editor.new(Pry.new)
  end

  describe "build_editor_invocation_string", skip: !Pry::Helpers::Platform.windows? do
    it 'should shell-escape files' do
      invocation_str = @editor.build_editor_invocation_string(@tf_path, 5, true)
      expect(invocation_str).to match(/#@tf_dir.+hello\\ world\.rb/)
    end
  end

  describe "build_editor_invocation_string on windows" do
    before do
      allow(Pry::Helpers::Platform).to receive(:windows?).and_return(true)
    end

    it "should not shell-escape files" do
      invocation_str = @editor.build_editor_invocation_string(@tf_path, 5, true)
      expect(invocation_str).to match(/hello world\.rb/)
    end
  end

  describe 'invoke_editor with a proc' do
    it 'should not shell-escape files' do
      editor = Pry::Editor.new(Pry.new(editor: proc { |file, line, blocking|
        @file = file
        nil
      }))

      editor.invoke_editor(@tf_path, 10, true)
      expect(@file).to eq(@tf_path)
    end
  end
end
