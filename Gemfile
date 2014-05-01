source 'https://rubygems.org'
gemspec
gem 'rake',  '~> 10.0'

group :development do
  gem 'gist'
  gem 'yard'
end

group :test do
  gem 'bacon', '~> 1.2'
  gem 'mocha', '~> 1.0', require: "mocha/api"
end

platform :rbx do
  gem 'rubysl-singleton'
  gem 'rubysl-prettyprint'
  gem 'rb-readline'
end
