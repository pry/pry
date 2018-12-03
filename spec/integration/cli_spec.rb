RSpec.describe 'The bin/pry CLI' do
  let(:ruby) { RbConfig.ruby.shellescape }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')).shellescape }

  context "ARGV forwarding" do
    let(:code) { 'p(ARGV) and exit'.shellescape }
    it "forwards its remaining arguments as ARGV when - is passed" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} - -a --b 3`.chomp
      expect(out).to eq(%w[-a --b 3].inspect)
    end

    it "forwards its remaining arguments when -- is passed" do
      out = `#{ruby} -I#{pry_dir} bin/pry --no-correct-indent -e #{code} -- -a --b 3`.chomp
      expect(out).to eq(%w[-a --b 3].inspect)
    end
  end
end
