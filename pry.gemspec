require File.expand_path('../lib/pry/version', __FILE__)

Gem::Specification.new do |s|
  s.name    = "pry"
  s.version = Pry::VERSION

  s.required_ruby_version = '>= 1.9.3'

  s.authors = [
    'John Mair (banisterfiend)',
    'Conrad Irwin',
    'Ryan Fitzgerald',
    'Kyrylo Silin'
  ]
  s.email = [
    'jrmair@gmail.com',
    'conrad.irwin@gmail.com',
    'rwfitzge@gmail.com',
    'silin@kyrylo.org'
  ]
  s.summary = "An IRB alternative and runtime developer console"
  s.description = s.summary
  s.homepage = "http://pryrepl.org"
  s.licenses = ['MIT']

  s.executables   = ["pry"]
  s.require_paths = ["lib"]
  s.files         = `git ls-files bin lib *.md LICENSE`.split("\n")

  s.add_dependency 'coderay',       '~> 1.1.0'
  s.add_dependency 'method_source', '~> 0.9.0'

  s.metadata['changelog_uri'] = 'https://github.com/pry/pry/blob/master/CHANGELOG.md'
  s.metadata['source_code_uri'] = 'https://github.com/pry/pry/'
  s.metadata['bug_tracker_uri'] = 'https://github.com/pry/pry/issues'
end
