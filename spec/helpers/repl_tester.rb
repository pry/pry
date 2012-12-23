# This is for super-high-level integration testing.

require 'thread'

class ReplTester
  class Input
    def initialize(tester_mailbox)
      @tester_mailbox = tester_mailbox
    end

    def readline(prompt)
      awaken_tester
      mailbox.pop
    end

    def mailbox
      Thread.current[:mailbox]
    end

    def awaken_tester
      @tester_mailbox.push nil
    end
  end

  def self.start(options = {}, &block)
    Thread.current[:mailbox] = Queue.new
    instance = nil

    redirect_pry_io Input.new(Thread.current[:mailbox]), StringIO.new do
      instance = new(options)
      instance.instance_eval(&block)
      instance.ensure_exit
    end
  ensure
    if instance && instance.thread && instance.thread.alive?
      instance.thread.kill
    end
  end

  attr_accessor :thread, :mailbox

  def initialize(options = {})
    @pry     = Pry.new(options)
    @repl    = Pry::REPL.new(@pry)
    @mailbox = Thread.current[:mailbox]

    @thread  = Thread.new do
      begin
        Thread.current[:mailbox] = Queue.new
        @repl.start
      ensure
        Thread.current[:session_ended] = true
        mailbox.push nil
      end
    end

    mailbox.pop # wait until the instance reaches its first readline
  end

  # Accept a line of input, as if entered by a user.
  def input(input)
    reset_output
    repl_mailbox.push input
    mailbox.pop # wait until the instance either calls readline or ends
  end

  # Assert that the current prompt matches the given string or regex.
  def prompt(match)
    match.should === @pry.select_prompt
  end

  # Assert that the most recent output (since the last time input was called)
  # matches the given string or regex.
  def output(match)
    match.should === Pry.output.string.chomp
  end

  # Assert that the Pry session ended naturally after the last input.
  def assert_exited
    @should_exit_naturally = true
  end

  # @private
  def ensure_exit
    if @should_exit_naturally
      @thread[:session_ended].should.be.true
    else
      input "exit-all"
      raise "REPL didn't die" unless @thread[:session_ended]
    end
  end

  private

  def reset_output
    @pry.output = Pry.output = StringIO.new
  end

  def repl_mailbox
    @thread[:mailbox]
  end
end
