# frozen_string_literal: true

require 'rbconfig'

RSpec.describe 'Bundler' do
  let(:ruby) { RbConfig.ruby.shellescape }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')).shellescape }

  context "when Pry requires Gemfile, which doesn't specify Pry as a dependency" do
    it "loads auto-completion correctly" do
      code = <<-RUBY
      require "pry"
      require "bundler/inline"

      # Silence the "The Gemfile specifies no dependencies" warning
      class Bundler::UI::Shell
        def warn(*args, &block); end
      end

      gemfile(true) do
        source "https://rubygems.org"
      end
      exit 42 if Pry.config.completer
      RUBY
      `#{ruby} -I#{pry_dir} -e'#{code}'`
      expect($CHILD_STATUS.exitstatus).to eq(42)
    end
  end
end
