# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'yard'
gem 'rspec'

gem 'fiddle'
gem 'psych', '<= 5.2.0'
gem 'ostruct', '0.6.0'

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
  gem 'method_source', '= 1.0.0'
end

# Rubocop supports only >=2.2.0
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
  gem 'rubocop', '= 0.66.0', require: false
end
