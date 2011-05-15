class Pry
  class PluginManager
    PRY_PLUGIN_PREFIX = /^pry-/

    class Plugin
      attr_accessor :name, :gem_name, :enabled

      def initialize(name, gem_name, enabled)
        @name, @gem_name, @enabled = name, gem_name, enabled
      end

      # Disable a plugin.
      def disable!
        self.enabled = false
      end
      alias enabled? enabled
    end

    def initialize
      @plugins = []
    end

    # Find all installed Pry plugins and store them in an internal array.
    def locate_plugins
      Gem.source_index.find_name('').each do |gem|
        next if gem.name !~ PRY_PLUGIN_PREFIX
        plugin_name = gem.name.split('-', 2).last
        @plugins << Plugin.new(plugin_name, gem.name, true)
      end
      @plugins
    end

    # @return [Hash] A hash with all plugin names (minus the 'pry-') as
    #   keys and Plugin objects as values.
    def plugins
      h = {}
      @plugins.each do |plugin|
        h[plugin.name] = plugin
      end
      h
    end

    # Require all enabled plugins, disabled plugins are skipped.
    def load_plugins
      @plugins.each do |plugin|
        require plugin.gem_name if plugin.enabled?
      end
    end
  end

end

