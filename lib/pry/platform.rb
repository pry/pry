class Pry
  module Platform

    module_function

    # have fun on the Windows platform.
    def windows?
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
    end

# are we able to use ansi on windows?
    def windows_ansi?
      defined?(Win32::Console) || ENV['ANSICON'] || (windows? && mri_20?)
    end

    def mri?
      RbConfig::CONFIG['ruby_install_name'] == 'ruby'
    end

    def mri_20?
      mri? && RUBY_VERSION =~ /2.0/
    end

  end
end
