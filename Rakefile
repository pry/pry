# frozen_string_literal: true

require 'rake/clean'
require 'rubygems/package_task'

$LOAD_PATH.unshift 'lib'
require 'pry/version'

CLOBBER.include('**/*~', '**/*#*', '**/*.log')
CLEAN.include(
  '**/*#*', '**/*#*.*', '**/*_flymake*.*', '**/*_flymake', '**/*.rbc', '**/.#*.*'
)

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task default: :spec

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
  Pry.start(TOPLEVEL_BINDING, input: StringIO.new('exit'))
end

def modify_base_gemspec
  # rubocop:disable Security/Eval
  eval(File.read('pry.gemspec')).tap { |s| yield s }
  # rubocop:enable Security/Eval
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

%w[mswin32 mingw32].each do |platform|
  namespace platform do
    spec = modify_base_gemspec do |s|
      s.add_dependency('win32console', '~> 1.3')
      s.platform = Gem::Platform.new ['universal', platform, nil]
    end

    Gem::PackageTask.new(spec) do |pkg|
      pkg.need_zip = false
      pkg.need_tar = false
    end
  end

  task gems: "#{platform}:gem"
end

desc "build all platform gems at once"
task gems: [:clean, :rmgems, 'ruby:gem', 'jruby:gem']

desc "remove all platform gems"
task rmgems: ['ruby:clobber_package']
task rm_gems: :rmgems
task rm_pkgs: :rmgems

desc "reinstall gem"
task reinstall: :gems do
  begin
    sh "gem uninstall pry"
  rescue StandardError
    nil
  end
  sh "gem install #{File.dirname(__FILE__)}/pkg/pry-#{Pry::VERSION}.gem"
end

task install: :reinstall

desc "build and push latest gems"
task pushgems: :gems do
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
  task test: :build do
    system(
      "docker run -i -t -v /tmp/prytmp:/tmp/prytmp pry/pry ./multi_test_inside_docker.sh"
    )
  end
end
