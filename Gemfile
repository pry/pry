source 'https://rubygems.org'
gemspec

# For Guard
group :development do
  gem 'jist'
  gem 'rb-inotify', :require => 'false'
  gem 'rb-fsevent', :require => 'false'
end

if RbConfig::CONFIG['ruby_install_name'] == 'rbx'
  gem 'rubysl-singleton'
  gem 'rb-readline'
end
