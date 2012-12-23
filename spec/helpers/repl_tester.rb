# This is for super-high-level integration testing.

require 'fiber'

class ReplTester
  class Input
    def readline(prompt)
      Fiber.yield(prompt)
    end
  end

  def self.start
    redirect_pry_io Input.new, StringIO.new do
      instance = new

      yield instance
      instance.in "exit-all"
      raise "REPL didn't die" if instance.fiber.alive?
    end
  end

  attr_accessor :pry, :repl, :fiber

  def initialize
    @pry   = Pry.new
    @repl  = Pry::REPL.new(@pry)

    @fiber = Fiber.new do
      @repl.start
    end

    @fiber.resume
  end

  def in(input)
    Pry.output.send(:initialize) # reset StringIO
    @fiber.resume(input)
  end

  def prompt(match)
    match.should === @pry.select_prompt
  end

  def out(match)
    match.should === Pry.output.string.chomp
  end
end
