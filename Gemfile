# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'yard'
gem 'rspec'
gem 'irb'

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3.0')
  gem 'reline'
  gem 'prism', '>= 0.25.0'
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
  gem 'rubocop', '1.85.0', require: false
else
  gem 'rubocop', require: false
end
