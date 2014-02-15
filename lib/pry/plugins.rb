class Pry
  class PluginManager
    PRY_PLUGIN_PREFIX = /^pry-/

    # Placeholder when no associated gem found, displays warning
    class NoPlugin
      def initialize(name)
        @name = name
      end

      def method_missing(*args)
        warn "Warning: The plugin '#{@name}' was not found! (no gem found)"
      end
    end

    class Plugin
      attr_accessor :name, :gem_name, :enabled, :spec, :active

      def initialize(name, gem_name, spec, enabled)
        @name, @gem_name, @enabled, @spec = name, gem_name, enabled, spec
      end

      # Disable a plugin. (prevents plugin from being loaded, cannot
      # disable an already activated plugin)
      def disable!
        self.enabled = false
      end

      # Enable a plugin. (does not load it immediately but puts on
      # 'white list' to be loaded)
      def enable!
        self.enabled = true
      end

      # Load the Command line options defined by this plugin (if they exist)
      def load_cli_options
        cli_options_file = File.join(spec.full_gem_path, "lib/#{spec.name}/cli.rb")
        require cli_options_file if File.exists?(cli_options_file)
      end
      # Activate the plugin (require the gem - enables/loads the
      # plugin immediately at point of call, even if plugin is
      # disabled)
      # Does not reload plugin if it's already active.
      def activate!
        # Create the configuration object for the plugin.
        Pry.config.send("#{gem_name.gsub('-', '_')}=", Pry::Config.from_hash({}))

        begin
          require gem_name if !active?
        rescue LoadError => e
          warn "Found plugin #{gem_name}, but could not require '#{gem_name}'"
          warn e
        rescue => e
          warn "require '#{gem_name}' # Failed, saying: #{e}"
        end

        self.active = true
        self.enabled = true
      end

      alias active? active
      alias enabled? enabled
    end

    def initialize
      @plugins = []
    end

    # Find all installed Pry plugins and store them in an internal array.
    def locate_plugins
      Gem.refresh
      (Gem::Specification.respond_to?(:each) ? Gem::Specification : Gem.source_index.find_name('')).each do |gem|
        next if gem.name !~ PRY_PLUGIN_PREFIX
        plugin_name = gem.name.split('-', 2).last
        @plugins << Plugin.new(plugin_name, gem.name, gem, true) if !gem_located?(gem.name)
      end
      @plugins
    end

    # @return [Hash] A hash with all plugin names (minus the 'pry-') as
    #   keys and Plugin objects as values.
    def plugins
      h = Hash.new { |_, key| NoPlugin.new(key) }
      @plugins.each do |plugin|
        h[plugin.name] = plugin
      end
      h
    end

    # Require all enabled plugins, disabled plugins are skipped.
    def load_plugins
      @plugins.each do |plugin|
        plugin.activate! if plugin.enabled?
      end
    end

    private
    def gem_located?(gem_name)
      @plugins.any? { |plugin| plugin.gem_name == gem_name }
    end
  end

end
