require 'guard/guard'

module ::Guard
  class Bacon < Guard
    def run_all
      system "rake spec"
      puts
      true
    end

    def run_on_changes(paths)
      paths.delete('some_lib')
      puts "Running: #{paths.join ' '}"
      if paths.size.zero?
        warn 'Running all tests'
        system 'rake recspec'
      else
        paths.each do |path|
          warn "Running #{path}"
          system "rake spec run=#{path}" or return
          warn "\e[32;1mNice!!\e[0m  Now running all specs, just to be sure."
          run_all
        end
      end
    end
  end
end

guard 'bacon' do
  def deduce_spec_from(token)
    %W(
      spec/#{token}_spec.rb
      spec/pry_#{token}_spec.rb
      spec/commands/#{token}_spec.rb
    ).each do |e|
      return e if File.exists? e
    end
    nil
  end

  Dir['lib/pry/**/*.rb'].each do |rb|
    rb[%r(lib/pry/(.+)\.rb$)]
    spec_rb = deduce_spec_from($1)
    if spec_rb
      # run as 'bundle exec guard -d' to see these.
      ::Guard::UI.debug "'#{rb}' maps to '#{spec_rb}'"
    else
      ::Guard::UI.debug "No map, so run all for: '#{rb}'"
    end
    next unless spec_rb
    watch(rb) do |m| spec_rb end
  end

  watch(%r{^lib/.+\.rb$}) do |m|
    return if deduce_spec_from(m[0])
    'some_lib'
  end

  watch(%r{^spec/.+\.rb$}) do |m| m end
end

# vim:ft=ruby
