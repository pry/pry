source 'https://rubygems.org'
gemspec
gem 'rake', '~> 10.0'

group :development do
  gem 'gist'
  gem 'yard'

  # Rubocop supports only >=2.2.0
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
    gem 'rubocop', '= 0.59.2', require: false
  end
end

group :test do
  gem 'rspec', '~> 3.8.0'
end

group :development, :test do
  gem 'simplecov', '~> 0.8.0'
end
