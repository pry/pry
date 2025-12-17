# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

gem 'rake'
gem 'yard'
gem 'rspec'
gem 'irb'

gem "psych", '<= 5.4.0'

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
  gem 'method_source', '= 1.0.0'
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3.0')
  gem 'reline'
  gem 'prism', '>= 0.25.0'
end

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
  gem 'rubocop', require: false
end
