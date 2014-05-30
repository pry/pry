# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pry/version', __FILE__)

Gem::Specification.new do |s|
  s.name    = "pry"
  s.version = Pry::VERSION

  s.authors = ["John Mair (banisterfiend)", "Conrad Irwin", "Ryan Fitzgerald"]
  s.email = ["jrmair@gmail.com", "conrad.irwin@gmail.com", "rwfitzge@gmail.com"]
  s.summary = "An IRB alternative and runtime developer console"
  s.description = s.summary
  s.homepage = "http://pryrepl.org"
  s.licenses = ['MIT']

  s.executables   = ["pry"]
  s.require_paths = ["lib"]
  s.files         = `git ls-files bin lib *.md LICENSE`.split("\n")

  s.add_dependency 'coderay',       '~> 1.1.0'
  s.add_dependency 'slop',          '~> 3.4'
  s.add_dependency 'method_source', '~> 0.8.1'
  s.add_development_dependency 'bundler', '~> 1.0'
end
