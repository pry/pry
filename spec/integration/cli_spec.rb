RSpec.describe 'The bin/pry CLI' do
  let(:ruby) { RbConfig.ruby.shellescape }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')).shellescape }

  context '-I path' do
    it 'adds an additional path to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = `#{ruby} -I#{pry_dir} bin/pry -I /added/at/cli -e '#{code}'`
      expect(out).to include('/added/at/cli')
    end

    it 'adds multiple additional paths to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = `#{ruby} -I#{pry_dir} bin/pry -I /added/at/cli -I /added/at/cli/also -e '#{code}'`
      expect(out).to include('/added/at/cli')
      expect(out).to include('/added/at/cli/also')
    end
  end
end
