require 'guard/guard'

module ::Guard
  class Bacon < Guard
    def run_all
      system "bundle exec bacon -Itest -q -a"
      puts
      true
    end

    def run_spec(path)
      if File.exists?(path)
        @success &&= system "bundle exec bacon -Itest -q #{path}"
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
  def deduce_test_from(token)
    "test/test_#{token}.rb"
  end

  Dir['lib/pry/*.rb'].each do |rb|
    rb[%r(lib/pry/(.+)\.rb$)]
    test_rb = deduce_test_from $1
    if File.exists?(test_rb)
      watch(rb) { test_rb }
    else
      exempt = %w(
        commands
        version
      ).map {|token| deduce_test_from token}
      puts 'Missing ' + test_rb if
        ENV['WANT_TEST_COMPLAINTS'] and not exempt.include?(test_rb)
    end
  end

  watch(%r{^lib/pry/commands/([^.]+)\.rb}) { |m| "test/test_commands/test_#{m[1]}.rb" }

  # If no such mapping exists, just run all of them
  watch(%r{^lib/}) { :all }

  # If we modified one test file, run it
  watch(%r{^test.*/test_.+\.rb$})
end

# vim:ft=ruby
