require 'helper'

describe Pry do
  describe 'loading rc files' do
    before do
      Pry::HOME_RC_FILE.replace "spec/fixtures/testrc"
      Pry::LOCAL_RC_FILE.replace "spec/fixtures/testrc/../testrc"
      Pry.instance_variable_set(:@initial_session, true)
      Pry.config.should_load_rc = true
      Pry.config.should_load_local_rc = true
    end

    after do
      Pry::HOME_RC_FILE.replace "~/.pryrc"
      Pry::LOCAL_RC_FILE.replace "./.pryrc"
      Pry.config.should_load_rc = false
      Object.remove_const(:TEST_RC) if defined?(TEST_RC)
    end

    it "should never run the rc file twice" do
      Pry.start(self, :input => StringIO.new("exit-all\n"), :output => StringIO.new)
      TEST_RC.should == [0]

      Pry.start(self, :input => StringIO.new("exit-all\n"), :output => StringIO.new)
      TEST_RC.should == [0]
    end

    # Resolving symlinks doesn't work on jruby 1.9 [jruby issue #538]
    unless Pry::Helpers::BaseHelpers.jruby_19?
      it "should not load the rc file twice if it's symlinked differently" do
        Pry::HOME_RC_FILE.replace "spec/fixtures/testrc"
        Pry::LOCAL_RC_FILE.replace "spec/fixtures/testlinkrc"

        Pry.start(self, :input => StringIO.new("exit-all\n"), :output => StringIO.new)

        TEST_RC.should == [0]
      end
    end

    it "should not load the pryrc if it cannot expand ENV[HOME]" do
      old_home = ENV['HOME']
      ENV['HOME'] = nil
      Pry.config.should_load_rc = true
      lambda { Pry.start(self, :input => StringIO.new("exit-all\n"), :output => StringIO.new) }.should.not.raise

      ENV['HOME'] = old_home
    end

    it "should not run the rc file at all if Pry.config.should_load_rc is false" do
      Pry.config.should_load_rc = false
      Pry.config.should_load_local_rc = false
      Pry.start(self, :input => StringIO.new("exit-all\n"), :output => StringIO.new)
      Object.const_defined?(:TEST_RC).should == false
    end

    describe "that raise exceptions" do
      before do
        Pry::HOME_RC_FILE = "spec/fixtures/testrcbad"
        Pry.config.should_load_local_rc = false

        putsed = nil

        # YUCK! horrible hack to get round the fact that output is not configured
        # at the point this message is printed.
        (class << Pry; self; end).send(:define_method, :puts) { |str|
          putsed = str
        }

        @doing_it = lambda{
          Pry.start(self, :input => StringIO.new("Object::TEST_AFTER_RAISE=1\nexit-all\n"), :output => StringIO.new)
          putsed
        }
      end

      after do
        Object.remove_const(:TEST_BEFORE_RAISE)
        Object.remove_const(:TEST_AFTER_RAISE)
        (class << Pry; undef_method :puts; end)
      end

      it "should not raise exceptions" do
        @doing_it.should.not.raise
      end

      it "should continue to run pry" do
        @doing_it[]
        Object.const_defined?(:TEST_BEFORE_RAISE).should == true
        Object.const_defined?(:TEST_AFTER_RAISE).should == true
      end

      it "should output an error" do
        @doing_it.call.split("\n").first.should =~
          %r{Error loading .*spec/fixtures/testrcbad: messin with ya}
      end
    end
  end
end
