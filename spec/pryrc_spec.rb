# frozen_string_literal: true

describe Pry do
  describe 'loading rc files' do
    before do
      Pry.config.rc_file = 'spec/fixtures/testrc'
      stub_const('Pry::LOCAL_RC_FILE', 'spec/fixtures/testrc/../testrc')

      Pry.instance_variable_set(:@initial_session, true)
      Pry.config.should_load_rc = true
      Pry.config.should_load_local_rc = true
    end

    after do
      Pry.config.should_load_rc = false
      Object.remove_const(:TEST_RC) if defined?(TEST_RC)
    end

    it "should never run the rc file twice" do
      Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)
      expect(TEST_RC).to eq [0]

      Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)
      expect(TEST_RC).to eq [0]
    end

    # Resolving symlinks doesn't work on jruby 1.9 [jruby issue #538]
    unless Pry::Helpers::Platform.jruby_19?
      it "should not load the rc file twice if it's symlinked differently" do
        Pry.config.rc_file = 'spec/fixtures/testrc'
        stub_const('Pry::LOCAL_RC_FILE', 'spec/fixtures/testlinkrc')

        Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)

        expect(TEST_RC).to eq [0]
      end
    end

    it "should not load the pryrc if pryrc's directory permissions do not allow this" do
      Dir.mktmpdir do |dir|
        File.chmod 0o000, dir
        stub_const('Pry::LOCAL_RC_FILE', File.join(dir, '.pryrc'))
        Pry.config.should_load_rc = true
        expect do
          Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)
        end.to_not raise_error
        File.chmod 0o777, dir
      end
    end

    it "should not load the pryrc if it cannot expand ENV[HOME]" do
      old_home = ENV['HOME']
      ENV['HOME'] = nil
      Pry.config.should_load_rc = true
      expect do
        Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)
      end.to_not raise_error

      ENV['HOME'] = old_home
    end

    it "should not run the rc file at all if Pry.config.should_load_rc is false" do
      Pry.config.should_load_rc = false
      Pry.config.should_load_local_rc = false
      Pry.start(self, input: StringIO.new("exit-all\n"), output: StringIO.new)
      expect(Object.const_defined?(:TEST_RC)).to eq false
    end

    describe "that raise exceptions" do
      before do
        Pry.config.rc_file = 'spec/fixtures/testrcbad'
        Pry.config.should_load_local_rc = false

        putsed = nil

        # YUCK! horrible hack to get round the fact that output is not configured
        # at the point this message is printed.
        (class << Pry; self; end).send(:define_method, :puts) do |str|
          putsed = str
        end

        @doing_it = lambda {
          input = StringIO.new("Object::TEST_AFTER_RAISE=1\nexit-all\n")
          Pry.start(self, input: input, output: StringIO.new)
          putsed
        }
      end

      after do
        Object.remove_const(:TEST_BEFORE_RAISE)
        Object.remove_const(:TEST_AFTER_RAISE)
        (class << Pry; undef_method :puts; end)
      end

      it "should not raise exceptions" do
        expect(&@doing_it).to_not raise_error
      end

      it "should continue to run pry" do
        @doing_it[]
        expect(Object.const_defined?(:TEST_BEFORE_RAISE)).to eq true
        expect(Object.const_defined?(:TEST_AFTER_RAISE)).to eq true
      end

      it "should output an error" do
        expect(@doing_it.call.split("\n").first).to match(
          %r{Error loading .*spec/fixtures/testrcbad: messin with ya}
        )
      end
    end
  end
end
