# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('../lib', __FILE__)
require 'pry/version'

Gem::Specification.new do |s|
  s.name = 'pry'
  s.version = Pry::VERSION

  s.author = 'John Mair (banisterfiend)'
  s.email = 'jrmair@gmail.com'

  s.executables << 'pry'
  s.homepage = 'http://banisterfiend.wordpress.com'
  s.summary = 'an IRB alternative and runtime developer console'
  s.description = 'an IRB alternative and runtime developer console'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")

  s.add_runtime_dependency('coderay', '>= 0.9.8')
  s.add_runtime_dependency('ruby_parser', '>= 2.0.5')
  s.add_runtime_dependency('slop', '~> 2.1.0')

  s.add_development_dependency('bacon', '>= 1.1.0')
  s.add_development_dependency('open4', '~> 1.0.1')
end
