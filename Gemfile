# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'yard'
gem 'rspec', '~> 3.8.0'

# TODO: unlock version when the bug is fixed:
# https://github.com/rspec/rspec-expectations/issues/1113
gem 'rspec-expectations', '= 3.8.2'

gem 'simplecov', '~> 0.16', require: false

# Rubocop supports only >=2.2.0
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
  gem 'rubocop', '= 0.66.0', require: false
end
