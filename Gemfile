source 'https://rubygems.org'
gemspec

# For Guard
group :development do
  gem 'jist'
  gem 'rb-inotify', :require => 'false'
  gem 'rb-fsevent', :require => 'false'
end

gem 'binding.repl'

if RbConfig::CONFIG['ruby_install_name'] == 'rbx'
  gem 'rubysl-singleton'
  gem 'rubysl-prettyprint'
  gem 'rb-readline'
end
