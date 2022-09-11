# frozen_string_literal: true

require 'rbconfig'

RSpec.describe 'The bin/pry CLI' do
  let(:call_pry) do
    lambda { |*args|
      pry_dir = File.expand_path(File.join(__FILE__, '../../../lib'))

      # the :err option is equivalent to 2>&1
      out = IO.popen([RbConfig.ruby,
                      "-I",
                      pry_dir,
                      'bin/pry',
                      *args,
                      err: %i[child out]], &:read)
      status = $CHILD_STATUS

      # Pry will emit silent garbage because of our auto indent feature.
      # This lambda cleans the output of that garbage.
      out = out.strip.sub(/^\e\[0[FG]/, "")

      [out, status]
    }
  end

  context "ARGV forwarding" do
    let(:code) { "p(ARGV) and exit" }

    it "forwards ARGV as an empty array when - is passed without following arguments" do
      out, status = call_pry.call('-e', code, '-')
      expect(status).to be_success
      expect(out).to eq([].inspect)
    end

    it "forwards ARGV as an empty array when -- is passed without following arguments" do
      out, status = call_pry.call('-e', code, '--')
      expect(status).to be_success
      expect(out).to eq([].inspect)
    end

    it "forwards its remaining arguments as ARGV when - is passed" do
      out, status = call_pry.call('-e', code, '-', '1', '-foo', '--bar', '--baz', 'daz')
      expect(status).to be_success
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end

    it "forwards its remaining arguments as ARGV when -- is passed" do
      out, status = call_pry.call('-e', code, '--', '1', '-foo', '--bar', '--baz', 'daz')
      expect(status).to be_success
      expect(out).to eq(%w[1 -foo --bar --baz daz].inspect)
    end
  end

  context '-I path' do
    it 'adds an additional path to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out, status = call_pry.call('-I', '/added/at/cli', '-e', code)
      expect(status).to be_success
      expect(out).to include('/added/at/cli')
    end

    it 'adds multiple additional paths to $LOAD_PATH' do
      code = 'p($LOAD_PATH) and exit'
      out, status = call_pry.call('-I', '/added-1/at/cli',
                                  '-I', '/added/at/cli/also',
                                  '-e', code)
      expect(status).to be_success
      expect(out).to include('/added-1/at/cli')
      expect(out).to include('/added/at/cli/also')
    end
  end
end
