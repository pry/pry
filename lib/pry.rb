# (C) John Mair (banisterfiend) 2010
# MIT License

direc = File.dirname(__FILE__)

require 'ruby_parser'
require 'method_source'
require "#{direc}/pry/version"
require "#{direc}/pry/input"
require "#{direc}/pry/output"

class Pry
  def self.start(target=TOPLEVEL_BINDING)
    new.repl(target)
  end

  def self.view(obj)
    case obj
    when String, Array, Hash, Symbol, nil
      obj.inspect
    else
      obj.to_s
    end
  end

  # class accessors
  class << self
    attr_reader :nesting
    attr_accessor :last_result
    attr_accessor :default_prompt, :wait_prompt
  end

  self.default_prompt = proc do |v, nest|
    if nest == 0
      "pry(#{Pry.view(v)})> "
    else
      "pry(#{Pry.view(v)}):#{Pry.view(nest)}> "
    end
  end
  
  self.wait_prompt = proc do |v, nest|
    if nest == 0
      "pry(#{Pry.view(v)})* "
    else
      "pry(#{Pry.view(v)}):#{Pry.view(nest)}* "
    end
  end

  attr_accessor :input, :output
  attr_accessor :default_prompt, :wait_prompt
  attr_reader :last_result
  
  def initialize(input = Input.new, output = Output.new)
    @input = input
    @output = output

    @default_prompt = Pry.default_prompt
    @wait_prompt = Pry.wait_prompt
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
  rescue SystemExit => e
    exit
  rescue Exception => e
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
    when "exit", "quit", "back", /^cd\s*\.\./
      output.exit
      throw(:breakout, nesting.level)
    when "ls"
      output.ls(target)
      eval_string.clear
    when /^cd\s+(.+)/
      obj = $~.captures.first
      target.eval("#{obj}.pry")
      eval_string.clear
    when /^show_method\s*(.+)/
      meth_name = ($~.captures).first
      code = get_method_source(target, meth_name, :method)
      output.show_method code
      eval_string.clear
    when /^show_instance_method\s*(.+)/
      meth_name = ($~.captures).first
      code = get_method_source(target, meth_name, :instance_method)
      output.show_method code
      eval_string.clear
    when /^jump_to\s*(\d*)/
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

  def get_method_source(target, meth_name, kind)
    target.eval("#{kind}(:#{meth_name}).source")
  end

  def prompt(eval_string, target, nest)
    target_self = target.eval('self')
    
    if eval_string.empty?
      default_prompt.call(target_self, nest)
    else
      wait_prompt.call(target_self, nest)
    end
  end

  if RUBY_VERSION =~ /1.9/
    require 'ripper'
    
    def valid_expression?(code)
      !!Ripper::SexpBuilder.new(code).parse
    end
    
  else
    
    def valid_expression?(code)
      RubyParser.new.parse(code)
    rescue Racc::ParseError, SyntaxError
      false
    else
      true
    end
    
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
      Pry.start(target)
    end
  end
end

class Object
  include Pry::ObjectExtensions
end
