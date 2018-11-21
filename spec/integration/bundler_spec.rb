RSpec.describe 'Bundler' do
  before :all do
    @ruby = RbConfig.ruby.shellescape
    @pry_dir = File.expand_path(File.join(__FILE__, '../../../lib')).shellescape
  end

  specify 'a LoadError is not raised after bundler has been activated' do
    code = <<-RUBY
    require "pry"
    require "bundler/inline"
    gemfile(true) do
      source "https://rubygems.org"
    end
    exit 42 if Pry.config.completer
    RUBY
    o = `#@ruby -I#@pry_dir -e'#{code}'`
    expect($?.exitstatus).to eq(42)
  end
end
