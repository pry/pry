# As a REPL, we often want to catch any unexpected exceptions that may have
# been raised; however we don't want to go overboard and prevent the user
# from exiting Pry when they want to.
module Pry::RescuableException
  def self.===(exception)
    case exception
      # Catch when the user hits ^C (Interrupt < SignalException), and assume
      # that they just wanted to stop the in-progress command (just like bash etc.)
    when Interrupt
      true
      # Don't catch signals (particularly not SIGTERM) as these are unlikely to be
      # intended for pry itself. We should also make sure that Kernel#exit works.
    when *Pry.config.exception_whitelist
      false
      # All other exceptions will be caught.
    else
      true
    end
  end
end
