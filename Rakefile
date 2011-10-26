require 'rake/clean'
require 'rake/gempackagetask'

$:.unshift 'lib'
require 'pry/version'

CLOBBER.include("**/*~", "**/*#*", "**/*.log")
CLEAN.include("**/*#*", "**/*#*.*", "**/*_flymake*.*", "**/*_flymake",
              "**/*.rbc", "**/.#*.*")

def apply_spec_defaults(s)
  s.name = "pry"
  s.summary = "An IRB alternative and runtime developer console"
  s.version = Pry::VERSION
  s.date = Time.now.strftime '%Y-%m-%d'
  s.author = "John Mair (banisterfiend)"
  s.email = 'jrmair@gmail.com'
  s.description = s.summary
  s.homepage = "http://pry.github.com"
  s.executables = ["pry"]
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
  s.add_dependency("ruby_parser",">= 2.3.1")
  s.add_dependency("coderay","~>0.9.8")
  s.add_dependency("slop","~>2.1.0")
  s.add_dependency("method_source","~>0.6.7")
  s.add_development_dependency("bacon","~>1.1.0")
  s.add_development_dependency("open4", "~>1.0.1")
  s.add_development_dependency("rake", "~>0.9")
end

desc "Set up and run tests"
task :default => [:test]

desc "Run tests"
task :test do
  sh "bacon -Itest -rubygems -a -q"
end

desc "profile pry's startup time"
task :profile do
  require 'profile'
  require 'pry'
  Pry.start(TOPLEVEL_BINDING, :input => StringIO.new('exit'))
end

desc "run pry"
task :pry do
  load 'bin/pry'
end

desc "show pry version"
task :version do
  puts "Pry version: #{Pry::VERSION}"
end

namespace :ruby do
  spec = Gem::Specification.new do |s|
    apply_spec_defaults(s)
    s.platform = Gem::Platform::RUBY
  end

  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end

  desc  "Generate gemspec file"
  task :gemspec do
    File.open("#{spec.name}.gemspec", "w") do |f|
      f << spec.to_ruby
    end
  end
end

namespace :jruby do
  spec = Gem::Specification.new do |s|
    apply_spec_defaults(s)
    s.add_dependency("spoon", "~>0.0.1")
    s.platform = "java"
  end

  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end
end


[:mingw32, :mswin32].each do |v|
  namespace v do
    spec = Gem::Specification.new do |s|
      apply_spec_defaults(s)
      s.add_dependency("win32console", "~>1.3.0")
      s.platform = "i386-#{v}"
    end

    Rake::GemPackageTask.new(spec) do |pkg|
      pkg.need_zip = false
      pkg.need_tar = false
    end
  end
end

desc "build all platform gems at once"
task :gems => [:clean, :rmgems, "ruby:gem", "mswin32:gem", "mingw32:gem", "jruby:gem"]

desc "remove all platform gems"
task :rmgems => ["ruby:clobber_package"]

desc "build and push latest gems"
task :pushgems => :gems do
  chdir("#{File.dirname(__FILE__)}/pkg") do
    Dir["*.gem"].each do |gemfile|
      sh "gem push #{gemfile}"
    end
  end
end
