# (C) John Mair (banisterfiend) 2010
# MIT License

direc = File.dirname(__FILE__)

require 'ruby_parser'
require "#{direc}/pry/version"
require "#{direc}/pry/input"
require "#{direc}/pry/output"

class Pry
  
  # class accessors
  class << self
    attr_reader :nesting
    attr_accessor :last_result
  end

  attr_accessor :input
  attr_accessor :output
  attr_reader :last_result
  attr_reader :default_prompt
  attr_reader :wait_prompt
  
  def initialize
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
  end

  @nesting = []

  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end

  def nesting
    self.class.nesting
  end

  def nesting=(v)
    self.class.nesting = v
  end
  
  # loop
  def repl(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    target_self = target.eval('self')
    output.session_start(target_self)

    nesting_level = nesting.size

    # Make sure _ exists
    target.eval("_ = Pry.last_result")
    
    break_level = catch(:breakout) do
      nesting << [nesting.size, target_self]
      loop do
        rep(target) 
      end
    end

    nesting.pop
    output.session_end(target_self)

    # we only enter here if :breakout has been thrown
    if nesting_level != break_level
      throw :breakout, break_level 
    end
    
    target_self
  end
  
  # print
  def rep(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    output.print re(target)
  end

  # eval
  def re(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    Pry.last_result = target.eval r(target)
    target.eval("_ = Pry.last_result")
  rescue StandardError => e
    e
  end

  # read
  def r(target=TOPLEVEL_BINDING)
    target = binding_for(target)
    eval_string = ""
    loop do
      val = input.read(prompt(eval_string, target, nesting.level))
      eval_string += "#{val.chomp}\n"
      process_commands(val, eval_string, target)
      
      break eval_string if valid_expression?(eval_string)
    end
  end
  
  def process_commands(val, eval_string, target)
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
    when /show_method\s*(\w*)/
      meth_name = ($~.captures).first
      file, line = target.eval("method(:#{meth_name}).source_location")
      input = Class.new do
        define_method(:initialize) do
          @f = File.open(file)
          (line - 1).times { @f.readline }
        end
        
        def read(prompt)
          @f.readline
        end
      end

      tp = Pry.new
      tp.input = input.new
      tp.r.display
      eval_string.clear
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

  def prompt(eval_string, target, nest)
    target_self = target.eval('self')
    
    if eval_string.empty?
      default_prompt.call(target_self, nest)
    else
      wait_prompt.call(target_self, nest)
    end
  end

  def valid_expression?(code)
    RubyParser.new.parse(code)
  rescue Racc::ParseError, SyntaxError
    false
  else
    true
  end

  def binding_for(target)
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
      Pry.new.start(target)
    end
  end
end

class Object
  include Pry::ObjectExtensions
end
