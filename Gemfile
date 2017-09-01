source 'https://rubygems.org'
gemspec
gem 'rake',  '~> 10.0'

group :development do
  gem 'gist'
  gem 'yard'
  gem 'rb-fsevent', :require => false
end

group :test do
  gem 'rspec', '~> 3.4.0'
end

group :development, :test do
  gem 'simplecov', '~> 0.8.0'
end

platform :rbx do
  gem 'rubysl-singleton'
  gem 'rubysl-prettyprint'
  gem 'rb-readline'
end
