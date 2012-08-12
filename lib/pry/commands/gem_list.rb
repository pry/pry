class Pry
  Pry::Commands.create_command "gem-list", "List and search installed gems." do |pattern|
    banner <<-BANNER
      Usage: gem-list [REGEX]

      List all installed gems, when a regex is provided, limit the output to those that
      match the regex.
    BANNER

    def process(pattern=nil)
      pattern = Regexp.compile(pattern || '')
      gems    = if Gem::Specification.respond_to?(:each)
                  Gem::Specification.select{|spec| spec.name =~ pattern }.group_by(&:name)
                else
                  Gem.source_index.gems.values.group_by(&:name).select { |gemname, specs| gemname =~ pattern }
                end

      gems.each do |gem, specs|
        specs.sort! do |a,b|
          Gem::Version.new(b.version) <=> Gem::Version.new(a.version)
        end

        versions = specs.each_with_index.map do |spec, index|
          index == 0 ? text.bright_green(spec.version.to_s) : text.green(spec.version.to_s)
        end

        output.puts "#{text.default gem} (#{versions.join ', '})"
      end
    end
  end
end
