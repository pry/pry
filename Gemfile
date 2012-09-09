source :rubygems
gemspec

# For Guard
case RUBY_PLATFORM
when /linux/i
  gem 'rb-inotify'
when /darwin/i
  gem 'rb-fsevent'
end
