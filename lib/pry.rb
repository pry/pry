# (C) John Mair (banisterfiend) 2010
# MIT License

direc = File.dirname(__FILE__)

require "method_source"
require "#{direc}/pry/version"
require "#{direc}/pry/input"
require "#{direc}/pry/output"
require "#{direc}/pry/commands"

class Pry
  def self.start(target=TOPLEVEL_BINDING, options={})
    options = {
      :input => Pry.input,
      :output => Pry.output
    }.merge!(options)

    new(options[:input], options[:output]).repl(target)
  end

  def self.view(obj)
    case obj
    when String, Array, Hash, Symbol, nil
      obj.inspect
    else
      obj.to_s
    end
  end

  def self.reset_defaults
    self.input = Input.new
    self.output = Output.new
    self.commands = Commands.new(self.output)

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
  end

  # class accessors
  class << self
    attr_reader :nesting
    attr_accessor :last_result
    attr_accessor :default_prompt, :wait_prompt
    attr_accessor :input, :output
    attr_accessor :commands
  end

  self.reset_defaults

  @nesting = []

  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end

  attr_accessor :input, :output
  attr_accessor :default_prompt, :wait_prompt
  attr_accessor :commands
  attr_reader :last_result
  
  def initialize(input = Pry.input, output = Pry.output)
    @input = input
    @output = output

    @default_prompt = Pry.default_prompt
    @wait_prompt = Pry.wait_prompt
    @commands = Commands.new(output)
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
      eval_string << "#{val.chomp}\n"
      process_commands(val, eval_string, target)
      
      break eval_string if valid_expression?(eval_string)
    end
  end
  
  def process_commands(val, eval_string, target)
    def eval_string.clear() replace("") end

    if action = commands.commands.find { |k, v| Array(k).any? { |a| a === val } }

      options = {
        :captures => $~ ? $~.captures : nil,
        :eval_string => eval_string,
        :target => target,
        :val => val,
        :nesting => nesting,
        :output => output
      }

      action.last.call(options)
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

  if RUBY_VERSION =~ /1.9/
    require 'ripper'
    
    def valid_expression?(code)
      !!Ripper::SexpBuilder.new(code).parse
    end
    
  else
    require 'ruby_parser'
    
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
        target.__binding__
      end
    end
  end

  module ObjectExtensions
    def pry(target=self)
      Pry.start(target)
    end

    def __binding__
      if is_a?(Module)
        return class_eval "binding"
      end

      unless respond_to? :__binding_impl__
        self.class.class_eval <<-EXTRA
        def __binding_impl__
          binding
        end
        EXTRA
      end

      __binding_impl__
    end
  end
end

class Object
  include Pry::ObjectExtensions
end
