$LOAD_PATH.unshift './lib'
require 'pry/version'
require 'pry/platform'

source 'https://rubygems.org'
gemspec
gem 'rake',  '~> 10.0'

# For Guard
group :development do
  gem 'gist'
  gem 'rb-inotify', :require => false
  gem 'rb-fsevent', :require => false
  if Pry::Platform.mri_19? # 1.9 compatible.
    gem 'yard', '= 0.8'
    gem 'kramdown', "= 1.14"
  else
    gem 'kramdown', '~> 1.16'
    gem 'yard', '~> 0.9'
  end
end

group :test do
  gem 'rspec', '~> 3.7.0'
end

group :development, :test do
  gem 'simplecov', '~> 0.8.0'
end

platform :rbx do
  gem 'rubysl-singleton'
  gem 'rubysl-prettyprint'
  gem 'rb-readline'
end
