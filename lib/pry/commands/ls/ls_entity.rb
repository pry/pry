require 'pry/commands/ls/grep'
require 'pry/commands/ls/formatter'
require 'pry/commands/ls/globals'
require 'pry/commands/ls/constants'
require 'pry/commands/ls/methods'
require 'pry/commands/ls/self_methods'
require 'pry/commands/ls/instance_vars'
require 'pry/commands/ls/local_names'
require 'pry/commands/ls/local_vars'

class Pry
  class Command::Ls < Pry::ClassCommand

    class LsEntity

      def initialize(opts)
        @interrogatee = opts[:interrogatee]
        @target = opts[:target]
        @no_user_opts = opts[:no_user_opts]
        @opts = opts[:opts]
        @sticky_locals = opts[:sticky_locals]
        @args = opts[:args]
        @grep = Grep.new(Regexp.new(opts[:opts][:G] || '.'))
      end

      def entities_table
        entities.map(&:write_out).reject { |o| !o }.join('')
      end

      private

      def grep(entity)
        entity.tap { |o| o.grep = @grep }
      end

      def globals
        grep(Globals.new(@target, @opts))
      end

      def constants
        grep(Constants.new(@interrogatee, @target, @no_user_opts, @opts))
      end

      def methods
        grep(Methods.new(@interrogatee, @no_user_opts, @opts))
      end

      def self_methods
        grep(SelfMethods.new(@interrogatee, @no_user_opts, @opts))
      end

      def instance_vars
        grep(InstanceVars.new(@interrogatee, @no_user_opts, @opts))
      end

      def local_names
        grep(LocalNames.new(@target, @no_user_opts, @sticky_locals, @args))
      end

      def local_vars
        LocalVars.new(@target, @sticky_locals, @opts)
      end

      def entities
        [globals, constants, methods, self_methods, instance_vars, local_names,
          local_vars]
      end

    end
  end
end
