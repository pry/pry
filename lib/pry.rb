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
  
  @output = Output.new
  @input = Input.new

  @default_prompt = proc do |v, nest|
    if nest == 0
      "pry(#{v.inspect})> "
    else
      "pry(#{v.inspect}):#{nest.inspect}> "
    end
  end
  
  @wait_prompt = proc do |v, nest|
    if nest == 0
      "pry(#{v.inspect})* "
    else
      "pry(#{v.inspect}):#{nest.inspect}* "
    end
  end
  
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
    
    break_level = catch(:breakout) do
      @nesting << [@nesting.size, target_self]
      loop do
         rep(target) 
      end
    end

    @nesting.pop
    output.session_end(target_self)

    # we only enter here if :breakout has been thrown
    if break_level && nesting_level != break_level
      throw :breakout, break_level 
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
    when "help"
      output.show_help
      eval_string.clear
    when "nesting"
      output.show_nesting(nesting)
      eval_string.clear
    when "status"
      output.show_status(nesting, target)
      eval_string.clear
    when "exit_all"
      throw(:breakout, 0)
    when "exit", "quit", "back"
      output.exit
      throw(:breakout, nesting.level)
    when /jump_to\s*(\d*)/
      break_level = ($~.captures).first.to_i
      output.jump_to(break_level)

      case break_level
      when nesting.level
        output.warn_already_at_level(nesting.level)
        eval_string.clear
      when (0...nesting.level)
        throw(:breakout, break_level + 1)
      else
        output.err_invalid_nest_level(break_level,
                                      nesting.level - 1)
        eval_string.clear
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
    def pry(target=self)
      Pry.start(target)
    end
  end
end

class Object
  include Pry::ObjectExtensions
end
