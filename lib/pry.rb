require 'rubygems'
require 'readline'
require 'ruby_parser'

module Pry
  class << self
    attr_accessor :default_prompt, :wait_prompt,
    :session_start_msg, :session_end_msg
  end
  
  @default_prompt = proc { |v| "pry(#{v})> " }
  @wait_prompt = proc { |v| "pry(#{v})* " }
  @session_start_msg = proc { |v| "Beginning Pry session for #{v}" }
  @session_end_msg = proc { |v| "Ending Pry session for #{v}" }
  
  # loop
  def self.repl(target=TOPLEVEL_BINDING)
    if !target.is_a?(Binding)
      target = target.instance_eval { binding }
    end
    
    puts session_start_msg.call(target.eval('self'))

    loop do
      if catch(:pop) { rep(target) } == :return
        break target.eval('self')
      end
    end

    puts session_end_msg.call(target.eval('self'))
  end

  class << self
    alias_method :into, :repl
    alias_method :start, :repl
  end
  
  # print
  def self.rep(target=TOPLEVEL_BINDING)
    if !target.is_a?(Binding)
      target = target.instance_eval { binding }
    end

    value = re(target)
    case value
    when Exception
      puts "#{value.class}: #{value.message}"
    else
      puts "=> #{value.inspect}"
    end
  end

  # eval
  def self.re(target=TOPLEVEL_BINDING)
    target.eval r(target)
  rescue StandardError => e
    e
  end

  # read
  def self.r(target=TOPLEVEL_BINDING)
    eval_string = ""
    loop do
      val = Readline.readline(prompt(eval_string, target), true)
      eval_string += "#{val}\n"
      process_commands(val, eval_string, target)
      
      break eval_string if valid_expression?(eval_string)
    end
  end
  
  def self.process_commands(val, eval_string, target)
    case val
    when "#exit", "#quit"
      exit
    when "!"
      eval_string.replace("")
      puts "Refreshed REPL."
    when "exit", "quit"
      throw(:pop, :return)
    end
  end

  def self.prompt(eval_string, target)
    context = target.eval('self')
    
    if eval_string.empty?
      default_prompt.call(context)
    else
      wait_prompt.call(context)
    end
  end

  def self.valid_expression?(code)
    RubyParser.new.parse(code)
  rescue Racc::ParseError
    false
  else
    true
  end
end
