source 'https://rubygems.org'
gemspec
gem 'rake',  '~> 10.0'

# For Guard
group :development do
  gem 'jist'
  gem 'rb-inotify', :require => false
  gem 'rb-fsevent', :require => false
end

group :test do
  gem 'bacon', '~> 1.2'
  gem 'mocha', '~> 1.0', require: "mocha/api"
end

group :development, :test do
  gem 'simplecov', '~> 0.8'
  gem 'bond',  '~> 0.5'
end

platform :rbx do
  gem 'rubysl-singleton'
  gem 'rubysl-prettyprint'
  gem 'rb-readline'
end
