# This is for super-high-level integration testing.

require 'thread'
require 'delegate'

class ReplTester
  class Input
    def initialize(tester_mailbox)
      @tester_mailbox = tester_mailbox
    end

    def readline(prompt)
      @tester_mailbox.push prompt
      mailbox.pop
    end

    def mailbox
      Thread.current[:mailbox]
    end
  end

  class Output < SimpleDelegator
    def clear
      __setobj__(StringIO.new)
    end
  end

  def self.start(options = {}, &block)
    Thread.current[:mailbox] = Queue.new
    instance = nil
    input    = Input.new(Thread.current[:mailbox])
    output   = Output.new(StringIO.new)

    redirect_pry_io input, output do
      instance = new(options)
      instance.instance_eval(&block)
      instance.ensure_exit
    end
  ensure
    if instance && instance.thread && instance.thread.alive?
      instance.thread.kill
    end
  end

  attr_accessor :thread, :mailbox, :last_prompt

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

    wait # wait until the instance reaches its first readline
  end

  # Accept a line of input, as if entered by a user.
  def input(input)
    reset_output
    repl_mailbox.push input
    wait
    Pry.output.string
  end

  # Assert that the current prompt matches the given string or regex.
  def prompt(match)
    match.should === last_prompt
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
    Pry.output.clear
  end

  def repl_mailbox
    @thread[:mailbox]
  end

  def wait
    @last_prompt = mailbox.pop
  end
end
