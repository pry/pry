require 'guard/guard'

module ::Guard
  class Bacon < Guard
    def run_all
      system "rake spec"
      puts
      true
    end

    def run_spec(path)
      if File.exists?(path)
        cmd = "bundle exec bacon -Ispec -q #{path}"
        puts cmd
        @success &&= system cmd
        puts
      end
    end

    def file_changed(path)
      run_spec(path)
    end

    def run_on_changes(paths)
      @success = true
      paths.delete(:all)

      paths.each do |path|
        file_changed(path)
      end

      run_all if @success
    end
  end
end

guard 'bacon' do
  def deduce_spec_from(token)
    "spec/#{token}_spec.rb"
  end

  Dir['lib/pry/*.rb'].each do |rb|
    rb[%r(lib/pry/(.+)\.rb$)]
    spec_rb = deduce_spec_from $1
    if File.exists?(spec_rb)
      watch(rb) { spec_rb }
    else
      exempt = %w(
        commands
        version
      ).map {|token| deduce_spec_from token}
      puts 'Missing ' + spec_rb if
        ENV['WANT_SPEC_COMPLAINTS'] and not exempt.include?(spec_rb)
    end
  end

  watch(%r{^lib/pry/commands/([^.]+)\.rb}) { |m| "spec/commands/#{m[1]}_spec.rb" }

  # If no such mapping exists, just run all of them
  watch(%r{^lib/}) { :all }

  # If we modified one spec file, run it
  watch(%r{^spec/.+\.rb$})
end

# vim:ft=ruby
