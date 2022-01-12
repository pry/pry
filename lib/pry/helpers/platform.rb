# frozen_string_literal: true

require 'rbconfig'

class Pry
  module Helpers
    # Contains methods for querying the platform that Pry is running on
    # @api public
    # @since v0.12.0
    module Platform
      # @return [Boolean]
      def self.mac_osx?
        !!(RbConfig::CONFIG['host_os'] =~ /\Adarwin/i)
      end

      # @return [Boolean]
      def self.linux?
        !!(RbConfig::CONFIG['host_os'] =~ /linux/i)
      end

      # @return [Boolean] true when Pry is running on Windows with ANSI support,
      #   false otherwise
      def self.windows?
        !!(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/)
      end

      # Checks older version of Windows console that required alternative
      # libraries to work with Ansi escapes codes.
      # @return [Boolean]
      def self.windows_ansi?
        # ensures that ConPty isn't available before checking anything else
        windows? && !!(windows_conpty? || defined?(Win32::Console) || Pry::Env['ANSICON'] || mri_2?)
      end

      # New version of Windows console that understands Ansi escapes codes.
      # @return [Boolean]
      def self.windows_conpty?
        @conpty ||= windows? && begin
          require 'fiddle/import'
          require 'fiddle/types'

          kernel32 = Module.new do
            extend Fiddle::Importer
            dlload 'kernel32'
            include Fiddle::Win32Types
            extern 'HANDLE GetStdHandle(DWORD)'
            extern 'BOOL GetConsoleMode(HANDLE, DWORD*)'
          end

          mode = kernel32.create_value('DWORD')

          std_output_handle = -11
          enable_virtual_terminal_processing = 0x4

          stdout_handle = kernel32.GetStdHandle(std_output_handle)

          stdout_handle > 0 &&
            kernel32.GetConsoleMode(stdout_handle, mode) != 0 &&
            mode.value & enable_virtual_terminal_processing != 0

        rescue LoadError, Fiddle::DLError
          false
        ensure
          Fiddle.free mode.to_ptr if mode
          kernel32.handler.handlers.each(&:close) if kernel32
        end
      end

      # @return [Boolean]
      def self.jruby?
        RbConfig::CONFIG['ruby_install_name'] == 'jruby'
      end

      # @return [Boolean]
      def self.jruby_19?
        jruby? && RbConfig::CONFIG['ruby_version'] == '1.9'
      end

      # @return [Boolean]
      def self.mri?
        RbConfig::CONFIG['ruby_install_name'] == 'ruby'
      end

      # @return [Boolean]
      def self.mri_19?
        mri? && RUBY_VERSION.start_with?('1.9')
      end

      # @return [Boolean]
      def self.mri_2?
        mri? && RUBY_VERSION.start_with?('2.')
      end
    end
  end
end
