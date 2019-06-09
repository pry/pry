# frozen_string_literal: true

class Pry
  # Env is a helper module to work with environment variables.
  #
  # @since ?.?.?
  # @api private
  module Env
    def self.[](key)
      return unless ENV.key?(key)

      value = ENV[key]
      return if value == ''

      value
    end
  end
end
