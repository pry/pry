# This is for super-high-level integration testing.

require 'fiber'

class ReplTester
  class Input
    def readline(prompt)
      Fiber.yield(prompt)
    end
  end

  def self.start(options = {}, &block)
    redirect_pry_io Input.new, StringIO.new do
      instance = new(options)
      instance.instance_eval(&block)
      instance.ensure_exit
    end
  end

  attr_accessor :pry, :repl, :fiber

  def initialize(options = {})
    @pry   = Pry.new(options)
    @repl  = Pry::REPL.new(@pry)

    @fiber = Fiber.new do
      @repl.start
    end

    @fiber.resume
  end

  def input(input)
    Pry.output.send(:initialize) # reset StringIO
    @fiber.resume(input)
  end

  def prompt(match)
    match.should === @pry.select_prompt
  end

  def output(match)
    match.should === Pry.output.string.chomp
  end

  def ensure_exit
    if @should_exit_naturally
      fiber.should.not.be.alive
    else
      input "exit-all"
      raise "REPL didn't die" if fiber.alive?
    end
  end

  def assert_exited
    @should_exit_naturally = true
  end
end
