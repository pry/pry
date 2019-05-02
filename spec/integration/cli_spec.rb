# frozen_string_literal: true

require 'rbconfig'

RSpec.describe 'The bin/pry CLI' do
  let(:ruby) { RbConfig.ruby.shellescape }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')).shellescape }
  let(:clean_output) do
    # Pry will emit silent garbage because of our auto indent feature.
    # This lambda cleans the output of that garbage.
    ->(out) { out.strip.sub("\e[0G", "") }
  end

  context "ARGV forwarding" do
    let(:code) { "p(ARGV) and exit".shellescape }

    it "forwards ARGV as an empty array when - is passed without following arguments" do
      out = clean_output.call(`#{ruby} -I#{pry_dir} bin/pry -e #{code} -`)
      expect(out).to eq([].inspect)
    end

    it "forwards ARGV as an empty array when -- is passed without following arguments" do
      out = clean_output.call(`#{ruby} -I#{pry_dir} bin/pry -e #{code} --`)
      expect(out).to eq([].inspect)
    end

    it "forwards its remaining arguments as ARGV when - is passed" do
      out = clean_output.call(
        `#{ruby} -I#{pry_dir} bin/pry -e #{code} - 1 -foo --bar --baz daz`
      )
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end

    it "forwards its remaining arguments as ARGV when -- is passed" do
      out = clean_output.call(
        `#{ruby} -I#{pry_dir} bin/pry -e #{code} -- 1 -foo --bar --baz daz`
      )
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end
  end

  context '-I path' do
    it 'adds an additional path to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = clean_output.call(
        `#{ruby} -I#{pry_dir} bin/pry -I /added/at/cli -e '#{code}'`
      )
      expect(out).to include('/added/at/cli')
    end

    it 'adds multiple additional paths to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out = clean_output.call(
        # rubocop:disable Metrics/LineLength
        `#{ruby} -I#{pry_dir} bin/pry -I /added-1/at/cli -I /added/at/cli/also -e '#{code}'`
        # rubocop:enable Metrics/LineLength
      )
      expect(out).to include('/added-1/at/cli')
      expect(out).to include('/added/at/cli/also')
    end
  end
end
