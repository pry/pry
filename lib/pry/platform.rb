module Pry::Platform
  extend self

  #
  # @return [Boolean]
  #  Returns true if Pry is running on Mac OSX.
  #
  # @note
  #   Queries RbConfig::CONFIG['host_os'] with a best guess.
  #
  def mac_osx? pry=(defined?(_pry_) and _pry_)
    !!(RbConfig::CONFIG['host_os'] =~ /\Adarwin/i)
  end

  #
  # @return [Boolean]
  #   Returns true if Pry is running on Linux.
  #
  # @note
  #   Queries RbConfig::CONFIG['host_os'] with a best guess.
  #
  def linux? pry=(defined?(_pry_) and _pry_)
    !!(RbConfig::CONFIG['host_os'] =~ /linux/i)
  end

  #
  # @return [Boolean]
  #   Returns true if Pry is running on Windows.
  #
  # @note
  #   Queries RbConfig::CONFIG['host_os'] with a best guess.
  #
  def windows? pry=(defined?(_pry_) and _pry_)
    !!(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/)
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is running on Windows with ANSI support.
  #
  def windows_ansi? pry=(defined?(_pry_) and _pry_)
    return false if not windows?
    !!(defined?(Win32::Console) or ENV['ANSICON'] or mri_2?)
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from JRuby.
  #
  def jruby? pry=(defined?(_pry_) and _pry_)
    RbConfig::CONFIG['ruby_install_name'] == 'jruby'
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from JRuby in 1.9 mode.
  #
  def jruby_19? pry=(defined?(_pry_) and _pry_)
    jruby? and RbConfig::CONFIG['ruby_version'] == '1.9'
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from Rubinius.
  #
  def rbx? pry=(defined?(_pry_) and _pry_)
    RbConfig::CONFIG['ruby_install_name'] == 'rbx'
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from MRI (CRuby).
  #
  def mri? pry=(defined?(_pry_) and _pry_)
    RbConfig::CONFIG['ruby_install_name'] == 'ruby'
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from MRI v1.9+ (CRuby).
  #
  def mri_19? pry=(defined?(_pry_) and _pry_)
    !!(mri? and RUBY_VERSION =~ /\A1\.9/)
  end

  #
  # @return [Boolean]
  #   Returns true when Pry is being run from MRI v2+ (CRuby).
  #
  def mri_2? pry=(defined?(_pry_) and _pry_)
    !!(mri? and RUBY_VERSION =~ /\A2/)
  end

  #
  #  @return [Array<Symbol>]
  #    Returns an Array of Ruby engines that Pry is known to run on.
  #
  def known_engines
    [:jruby, :rbx, :mri]
  end
end
