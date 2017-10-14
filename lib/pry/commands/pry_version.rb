class Pry::Command::Version < Pry::ClassCommand
  match 'pry-version'
  group 'Misc'
  description 'Show Pry version.'

  banner <<-'BANNER'
    Show Pry version.
  BANNER

  def process
    _pry_.pager.page version_string
  end

  private
  def version_string
    "#{_pry_.h.bright_blue('Pry')} v#{Pry::VERSION} " \
    "(codename: #{_pry_.h.bold(Pry::VERSION_CODENAME)}) " \
    "running on #{_pry_.h.bright_red('Ruby')} v#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}. " \
    "#{engine_string}\n"
  end

  def engine_string
    "Engine: #{RUBY_ENGINE}" if defined?(RUBY_ENGINE) and RUBY_ENGINE != "ruby"
  end

  Pry::Commands.add_command(self)
end
