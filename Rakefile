require 'rake/clean'
require 'rubygems/package_task'

$:.unshift 'lib'
require 'pry/version'

CLOBBER.include('**/*~', '**/*#*', '**/*.log')
CLEAN.include('**/*#*', '**/*#*.*', '**/*_flymake*.*', '**/*_flymake', '**/*.rbc', '**/.#*.*')

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

unless [].respond_to? :shuffle!
  class Array
    def shuffle!
      # TODO: fill this in if anyone cares
      self
    end
  end
end

def run_specs paths
  quiet = ENV['VERBOSE'] ? '' : '-q'
  exec "bacon -Ispec -rubygems #{quiet} #{paths.join ' '}"
end

desc "Run tests"
task :test do
  check_dependencies unless ENV['SKIP_DEP_CHECK']
  paths =
    if explicit_list = ENV['run']
      explicit_list.split(',')
    else
      Dir['spec/**/*_spec.rb'].shuffle!
    end
  run_specs paths
end
task :spec => :test

task :recspec do
  all = Dir['spec/**/*_spec.rb'].sort_by{|path| File.mtime(path)}.reverse
  warn "Running all, sorting by mtime: #{all[0..2].join(' ')} ...etc."
  run_specs all
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

def modify_base_gemspec
  eval(File.read('pry.gemspec')).tap { |s| yield s }
end

namespace :ruby do
  spec = modify_base_gemspec do |s|
    s.platform = Gem::Platform::RUBY
  end

  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = false
    pkg.need_tar = false
  end
end

namespace :jruby do
  spec = modify_base_gemspec do |s|
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
    spec = modify_base_gemspec do |s|
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
task :rm_gems => :rmgems
task :rm_pkgs => :rmgems

desc "reinstall gem"
task :reinstall => :gems do
  sh "gem uninstall pry" rescue nil
  sh "gem install #{File.dirname(__FILE__)}/pkg/pry-#{Pry::VERSION}.gem"
end

task :install => :reinstall

desc "build and push latest gems"
task :pushgems => :gems do
  chdir("#{File.dirname(__FILE__)}/pkg") do
    Dir["*.gem"].each do |gemfile|
      sh "gem push #{gemfile}"
    end
  end
end
