# (C) John Mair (banisterfiend) 2010
# MIT License

direc = File.dirname(__FILE__)

require 'ruby_parser'
require "#{direc}/pry/version"
require "#{direc}/pry/input"
require "#{direc}/pry/output"

module Pry
  
  # class accessors
  class << self
    attr_reader :nesting
    attr_reader :last_result
    attr_accessor :default_prompt
    attr_accessor :wait_prompt
    attr_accessor :input
    attr_accessor :output
  end
  
  @default_prompt = lambda do |v, nest|
    if nest == 0
      "pry(#{v.inspect})> "
    else
      "pry(#{v.inspect}):#{nest.inspect}> "
    end
  end
  
  @wait_prompt = lambda do |v, nest|
    if nest == 0
      "pry(#{v.inspect})* "
    else
      "pry(#{v.inspect}):#{nest.inspect}* "
    end
  end
  
  @output = Output.new
  @input = Input.new
  
  @nesting = []

  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end
  
  # loop
  def self.repl(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    target_self = target.eval('self')
    output.session_start(target_self)

    nesting_level = @nesting.size

    # Make sure _ exists
    target.eval("_ = Pry.last_result")
    
    nesting_level_breakout = catch(:breakout) do
      @nesting << [@nesting.size, target_self]
      loop do
         rep(target) 
      end
    end

    @nesting.pop
    output.session_end(target_self)

    # we only enter here if :breakout has been thrown
    if nesting_level_breakout
      throw :breakout, nesting_level_breakout if nesting_level != nesting_level_breakout
    end
    
    target_self
  end
  
  class << self
    alias_method :into, :repl
    alias_method :start, :repl
  end
  
  # print
  def self.rep(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    output.print re(target)
  end

  # eval
  def self.re(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    @last_result = target.eval r(target)
    target.eval("_ = Pry.last_result")
  rescue StandardError => e
    e
  end

  # read
  def self.r(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    eval_string = ""
    loop do
      val = input.read(prompt(eval_string, target, nesting.level))
      eval_string += "#{val}\n"
      process_commands(val, eval_string, target)
      
      break eval_string if valid_expression?(eval_string)
    end
  end
  
  def self.process_commands(val, eval_string, target)
    def eval_string.clear() replace("") end
    
    case val
    when "exit_program", "quit_program"
      output.exit_program
      exit
    when "!"
      output.refresh
      eval_string.clear
    when "nesting"
      output.show_nesting(nesting)
      eval_string.clear
    when "exit_all"
      throw(:breakout, 0)
    when "exit", "quit", "back"
      output.exit
      throw(:breakout, nesting.level)
    when /exit_at\s*(\d*)/, /jump_to\s*(\d*)/
      nesting_level_breakout = ($~.captures).first.to_i
      output.exit_at(nesting_level_breakout)
      
      if nesting_level_breakout < 0 || nesting_level_breakout >= nesting.level
        output.error_invalid_nest_level(nesting_level_breakout, nesting.level - 1)
        eval_string.clear
      else
        throw(:breakout, nesting_level_breakout + 1)
      end
    end
  end

  def self.prompt(eval_string, target, nest)
    target_self = target.eval('self')
    
    if eval_string.empty?
      default_prompt.call(target_self, nest)
    else
      wait_prompt.call(target_self, nest)
    end
  end

  def self.valid_expression?(code)
    RubyParser.new.parse(code)
  rescue Racc::ParseError, SyntaxError
    false
  else
    true
  end

  def self.binding_for(target)
    if target.is_a?(Binding)
      target
    else
      if target == TOPLEVEL_BINDING.eval('self')
        TOPLEVEL_BINDING
      else
        target.instance_eval { binding }
      end
    end
  end

  module ObjectExtensions
    def pry
      Pry.start(Pry.binding_for(self))
    end
  end
end

class Object
  include Pry::ObjectExtensions
end
