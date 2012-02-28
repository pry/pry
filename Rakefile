require 'rake/clean'
require 'rubygems/package_task'

$:.unshift 'lib'
require 'pry/version'

CLOBBER.include('**/*~', '**/*#*', '**/*.log')
CLEAN.include('**/*#*', '**/*#*.*', '**/*_flymake*.*', '**/*_flymake', '**/*.rbc', '**/.#*.*')

def apply_spec_defaults(s)
  s.name = 'pry'
  s.summary = "An IRB alternative and runtime developer console"
  s.version = Pry::VERSION
  s.date = Time.now.strftime '%Y-%m-%d'
  s.author = "John Mair (banisterfiend)"
  s.email = 'jrmair@gmail.com'
  s.description = s.summary
  s.homepage = 'http://pry.github.com'
  s.executables = ['pry']
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
  s.add_dependency('coderay', '~> 1.0.5')
  s.add_dependency('slop', ['>= 2.4.4', '< 3'])
  s.add_dependency('method_source','~> 0.7.1')
  s.add_development_dependency('bacon', '~> 1.1')
  s.add_development_dependency('open4', '~> 1.3')
  s.add_development_dependency('rake', '~> 0.9')
end

def check_dependencies
  require 'bundler'
  Bundler.definition.missing_specs

  eval('nil', TOPLEVEL_BINDING, '<main>') # workaround for issue #395
rescue LoadError
  # if Bundler isn't installed, we'll just assume your setup is ok.
rescue Bundler::GemNotFound
  raise RuntimeError, "You're missing one or more required gems. Run `bundle install` first."
end

desc "Set up and run tests"
task :default => [:test]

desc "Run tests"
task :test do
  check_dependencies unless ENV['SKIP_DEP_CHECK']
  sh "bacon -Itest -rubygems -a -q"
end

desc "Run pry"
task :pry do
  check_dependencies unless ENV['SKIP_DEP_CHECK']
  load 'bin/pry'
end

desc "Show pry version"
task :version do
  puts "Pry version: #{Pry::VERSION}"
end

desc "Profile pry's startup time"
task :profile do
  require 'profile'
  require 'pry'
  Pry.start(TOPLEVEL_BINDING, :input => StringIO.new('exit'))
end

desc "Build the gemspec file"
task :gemspec => "ruby:gemspec"

namespace :ruby do
  spec = Gem::Specification.new do |s|
    apply_spec_defaults(s)
    s.platform = Gem::Platform::RUBY
  end

  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end

  task :gemspec do
    File.open("#{spec.name}.gemspec", "w") do |f|
      f << spec.to_ruby
    end
  end
end

namespace :jruby do
  spec = Gem::Specification.new do |s|
    apply_spec_defaults(s)
    s.add_dependency('spoon', '~> 0.0')
    s.platform = 'java'
  end

  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end
end


[:mingw32, :mswin32].each do |v|
  namespace v do
    spec = Gem::Specification.new do |s|
      apply_spec_defaults(s)
      s.add_dependency('win32console', '~> 1.3')
      s.platform = "i386-#{v}"
    end

    Gem::PackageTask.new(spec) do |pkg|
      pkg.need_zip = false
      pkg.need_tar = false
    end
  end
end

desc "build all platform gems at once"
task :gems => [:clean, :rmgems, 'ruby:gem', 'mswin32:gem', 'mingw32:gem', 'jruby:gem']

desc "remove all platform gems"
task :rmgems => ['ruby:clobber_package']

desc "reinstall gem"
task :reinstall => :gems do
  sh "gem uninstall pry" rescue nil
  sh "gem install #{File.dirname(__FILE__)}/pkg/pry-#{Pry::VERSION}.gem"
end

desc "build and push latest gems"
task :pushgems => :gems do
  chdir("#{File.dirname(__FILE__)}/pkg") do
    Dir["*.gem"].each do |gemfile|
      sh "gem push #{gemfile}"
    end
  end
end
