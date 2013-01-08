class Pry
  module Rubygem

    class << self
      def installed?(name)
        require 'rubygems'
        if Gem::Specification.respond_to?(:find_all_by_name)
          Gem::Specification.find_all_by_name(name).any?
        else
          Gem.source_index.find_name(name).first
        end
      end

      # Get the gem spec object for the given gem name.
      #
      # @param [String] name
      # @return [Gem::Specification]
      def spec(name)
        specs = if Gem::Specification.respond_to?(:each)
                  Gem::Specification.find_all_by_name(name)
                else
                  Gem.source_index.find_name(name)
                end

        spec = specs.sort_by{ |spec| Gem::Version.new(spec.version) }.first

        spec or raise CommandError, "Gem `#{name}` not found"
      end

      # List gems matching a pattern.
      #
      # @param [Regexp] pattern
      # @return [Array<Gem::Specification>]
      def list(pattern = /.*/)
        if Gem::Specification.respond_to?(:each)
          Gem::Specification.select{|spec| spec.name =~ pattern }
        else
          Gem.source_index.gems.values.select{|spec| spec.name =~ pattern }
        end
      end

      # Completion function for gem-cd and gem-open.
      #
      # @param [String] so_far what the user's typed so far
      # @return [Array<String>] completions
      def complete(so_far)
        if so_far =~ / ([^ ]*)\z/
          self.list(%r{\A#{$2}}).map(&:name)
        else
          self.list.map(&:name)
        end
      end
    end

  end
end
