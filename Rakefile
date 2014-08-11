require 'rake/clean'
require 'rubygems/package_task'

$:.unshift 'lib'
require 'pry/version'

CLOBBER.include('**/*~', '**/*#*', '**/*.log')
CLEAN.include('**/*#*', '**/*#*.*', '**/*_flymake*.*', '**/*_flymake', '**/*.rbc', '**/.#*.*')

desc "Set up and run tests"
task :default => [:test]

def self.run_specs paths
  quiet   = ENV['VERBOSE'] ? '' : '-q'
  command = "bacon -Ispec -rubygems #{quiet} #{paths.join ' '}"
  $stderr.puts command if Rake::FileUtilsExt.verbose_flag.equal?(true)
  exec command
end

desc "Run tests"
task :test do
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

desc "Run pry (you can pass arguments using _ in place of -)"
task :pry do
  ARGV.shift if ARGV.first == "pry"
  ARGV.map! do |arg|
    arg.sub(/^_*/) { |m| "-" * m.size }
  end
  load 'bin/pry'
end

desc "Show pry version."
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


['i386-mingw32', 'i386-mswin32', 'x64-mingw32'].each do |platform|
  namespace platform do
    spec = modify_base_gemspec do |s|
      s.add_dependency('win32console', '~> 1.3')
      s.platform = platform
    end

    Gem::PackageTask.new(spec) do |pkg|
      pkg.need_zip = false
      pkg.need_tar = false
    end
  end
end

desc "build all platform gems at once"
task :gems => [:clean, :rmgems, 'ruby:gem', 'i386-mswin32:gem', 'i386-mingw32:gem', 'x64-mingw32:gem', 'jruby:gem']

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

namespace :docker do
  desc "build a docker container with multiple rubies"
  task :build do
    system "docker build -t pry/pry ."
  end

  desc "test pry on multiple ruby versions"
  task :test => :build do
    system "docker run -i -t -v /tmp/prytmp:/tmp/prytmp pry/pry ./multi_test_inside_docker.sh"
  end
end
