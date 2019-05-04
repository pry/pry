class Pry
  # @api private
  # @since ?.?.?
  module Warning
    # Prints a warning message with exact file and line location, similar to how
    # Ruby's -W prints warnings.
    #
    # @param [String] message
    # @return [void]
    def self.warn(message)
      if Kernel.respond_to?(:caller_locations)
        location = caller_locations(1..1).first
        path = location.path
        lineno = location.lineno
      else
        # Ruby 1.9.3 support.
        frame = caller.first.split(':') # rubocop:disable Performance/Caller
        path = frame.first
        lineno = frame[1]
      end

      Kernel.warn("#{path}:#{lineno}: warning: #{message}")
    end
  end
end
