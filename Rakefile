dlext = Config::CONFIG['DLEXT']
direc = File.dirname(__FILE__)

require 'rake/clean'
require 'rake/gempackagetask'
require "#{direc}/lib/pry/version"

CLOBBER.include("**/*.#{dlext}", "**/*~", "**/*#*", "**/*.log", "**/*.o")
CLEAN.include("ext/**/*.#{dlext}", "ext/**/*.log", "ext/**/*.o",
              "ext/**/*~", "ext/**/*#*", "ext/**/*.obj", "**/*#*", "**/*#*.*",
              "ext/**/*.def", "ext/**/*.pdb", "**/*_flymake*.*", "**/*_flymake")

def apply_spec_defaults(s)
  s.name = "pry"
  s.summary = "attach an irb-like session to any object at runtime"
  s.version = Pry::VERSION
  s.date = Time.now.strftime '%Y-%m-%d'
  s.author = "John Mair (banisterfiend)"
  s.email = 'jrmair@gmail.com'
  s.description = s.summary
  s.require_path = 'lib'
  s.add_dependency("ruby_parser",">=2.0.5")
  s.add_dependency("method_source",">=0.2.0")
  s.add_development_dependency("bacon",">=1.1.0")
  s.homepage = "http://banisterfiend.wordpress.com"
  s.has_rdoc = 'yard'
  s.files = Dir["ext/**/extconf.rb", "ext/**/*.h", "ext/**/*.c", "lib/**/*.rb",
                     "test/*.rb", "CHANGELOG", "README.markdown", "Rakefile", ".gemtest"]
end

task :test do
  sh "bacon -k #{direc}/test/test.rb"
end

desc "display the Pry version"
task :show_version do
  puts "Pry version: #{Pry::VERSION}"
end

desc "run pry"
task :pry do
  require "#{direc}/lib/pry.rb"
  Pry.start
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
end

desc "build all platform gems at once"
task :gems => [:rmgems, "ruby:gem"]

desc "remove all platform gems"
task :rmgems => ["ruby:clobber_package"]

desc "build and push latest gems"
task :pushgems => :gems do
  chdir("#{direc}/pkg") do
    Dir["*.gem"].each do |gemfile|
      sh "gem push #{gemfile}"
    end
  end
end
