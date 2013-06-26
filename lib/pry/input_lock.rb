require 'thread'

class Pry
  # There is one InputLock per input (such as STDIN) as two REPLs on the same
  # input makes things delirious. InputLock serializes accesses to the input so
  # that threads to not conflict with each other. The latest thread to request
  # ownership of the input wins.
  class InputLock
    class Interrupt < Exception; end

    def self.hook(input)
      input.instance_eval { @pry_lock ||= Pry::InputLock.new }
      def input.pry_lock
        @pry_lock
      end
    end

    def initialize
      @mutex = Mutex.new
      @cond = ConditionVariable.new
      @owners = []
      @interruptible = false
    end

    # Adds ourselves to the ownership list. The last one in the list may access
    # the input through interruptible_region().
    def __register_ownership(&block)
      @mutex.synchronize do
        # Three cases:
        # 1) There are no owners, in this case we are good to go.
        # 2) The current owner of the input is not reading the input (it might
        #    just be evaluating some ruby that the user typed).
        #    The current owner will figure out that it cannot go back to reading
        #    the input since we are adding ourselves to the @owners list, which
        #    in turns makes us the current owner.
        # 3) The owner of the input is in the interruptible region, reading from
        #    the input. It's safe to send an Interrupt exception to interrupt
        #    the owner. It will then proceed like in case 2).
        #    Note that we set the @interruptible flag to false to avoid having
        #    another thread sending an interrupt to us as we are adding
        #    ourselves to the @owners list, making us the current owner.
        if @interruptible
          @owners.last.raise Interrupt
          @interruptible = false
        end
        @owners << Thread.current
      end

      block.call

    ensure
      @mutex.synchronize do
        # We are releasing any desire to have the input ownership by removing
        # ourselves from the list.
        @owners.delete(Thread.current)

        # We need to wake up the thread at the end of the @owners list, but
        # sadly Ruby doesn't allow us to choose which one we wake up, so we wake
        # them all up.
        @cond.broadcast
      end
    end

    def register_ownership(&block)
      # If we already registered the thread (nested pry context), we do nothing.
      nested = @mutex.synchronize { @owners.include?(Thread.current) }
      nested ? block.call : __register_ownership(&block)
    end

    def interruptible_region(&block)
      @mutex.synchronize do
        # We patiently wait until we are the owner. This may happen as another
        # thread calls register_ownership() because of a binding.pry happening in
        # another thread.
        @cond.wait(@mutex) until @owners.last == Thread.current

        # We are the legitimate owner of the input. We mark ourselves as
        # interruptible, so other threads can send us an Interrupt exception
        # while we are blocking from reading the input.
        @interruptible = true
      end

      block.call

    rescue Interrupt
      # We were asked to back off as we are no longer the owner. The one sending
      # the interrupt has already set the @interruptible flag to false.
      retry

    ensure
      # Once we leave, we cannot receive an Interrupt, as it might disturb code
      # that is not tolerant to getting an exception in random places.
      @mutex.synchronize { @interruptible = false }
    end
  end
end
