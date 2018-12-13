RSpec.describe 'The bin/pry CLI' do
  let(:ruby) { RbConfig.ruby.shellescape }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')).shellescape }

  context "ARGV forwarding" do
    let(:code) { "p(ARGV) and exit".shellescape }

    it "forwards ARGV as an empty array when - is passed without following arguments" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} -`.chomp
      expect(out).to eq([].inspect)
    end

    it "forwards ARGV as an empty array when -- is passed without following arguments" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} --`.chomp
      expect(out).to eq([].inspect)
    end

    it "forwards its remaining arguments as ARGV when - is passed" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} - 1 -foo --bar --baz daz`.chomp
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end

    it "forwards its remaining arguments as ARGV when -- is passed" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} -- 1 -foo --bar --baz daz`.chomp
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end
  end

  context '-I path' do
    it 'adds an additional path to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = `#{ruby} -I#{pry_dir} bin/pry -I /added/at/cli -e '#{code}'`
      expect(out).to include('/added/at/cli')
    end

    it 'adds multiple additional paths to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = `#{ruby} -I#{pry_dir} bin/pry -I /added-1/at/cli -I /added/at/cli/also -e '#{code}'`
      expect(out).to include('/added-1/at/cli')
      expect(out).to include('/added/at/cli/also')
    end
  end
end
