# frozen_string_literal: true

require 'rbconfig'

RSpec.describe 'Bundler', slow: true do
  let(:ruby) { RbConfig.ruby }
  let(:pry_dir) { File.expand_path(File.join(__FILE__, '../../../lib')) }

  context "when Pry requires Gemfile, which doesn't specify Pry as a dependency" do
    it "loads auto-completion correctly" do
      code = <<-RUBY
      require "bundler"
      require "bundler/inline"
      require "pry"

      # Silence the "The Gemfile specifies no dependencies" warning
      class Bundler::UI::Shell
        def warn(*args, &block); end
      end

      gemfile(true) do
        source "https://rubygems.org"
      end
      exit 42 if Pry.config.completer
      RUBY
      IO.popen([ruby, '-I', pry_dir, '-e', code, err: [:child, :out]], &:read)
      expect($CHILD_STATUS.exitstatus).to eq(42)
    end
  end
end
