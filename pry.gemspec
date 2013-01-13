# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pry/version', __FILE__)

Gem::Specification.new do |s|
  s.name    = "pry"
  s.version = Pry::VERSION

  s.authors = ["John Mair (banisterfiend)", "Conrad Irwin", "Ryan Fitzgerald"]
  s.email = ["jrmair@gmail.com", "conrad.irwin@gmail.com", "rwfitzge@gmail.com"]
  s.summary = "An IRB alternative and runtime developer console"
  s.description = s.summary
  s.homepage = "http://pry.github.com"

  s.executables   = ["pry"]
  s.require_paths = ["lib"]
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")

  s.add_dependency 'coderay',       '~> 1.0.5'
  s.add_dependency 'slop',          '~> 3.4'
  s.add_dependency 'method_source', '~> 0.8'

  s.add_development_dependency 'bacon', '~> 1.2'
  s.add_development_dependency 'open4', '~> 1.3'
  s.add_development_dependency 'rake',  '~> 0.9'
  s.add_development_dependency 'guard', '~> 1.3.2'
  s.add_development_dependency 'mocha', '~> 0.13.1'
  # TODO: make this a plain dependency:
  s.add_development_dependency 'bond',  '~> 0.4.2'
end
