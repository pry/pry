# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'yard'
gem 'rspec'

gem "psych", '<= 5.2.0'

# Rubocop supports only >=2.2.0
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
  gem 'rubocop', '= 0.66.0', require: false
end
