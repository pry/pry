require 'rubygems'
require 'readline'
require 'ruby_parser'

module Pry
  DEFAULT_PROMPT = proc { |v| "pry(#{v})> " }
  DEFAULT_WAIT_PROMPT = proc { |v| "pry(#{v})* " }

  # loop
  def self.repl(target=TOPLEVEL_BINDING)
    if !target.is_a?(Binding)
      target = target.instance_eval { binding }
    end
    
    loop do
      if catch(:pop) { rep(target) } == :return
        return target.eval('self')
      end
    end
  end

  # print
  def self.rep(target=TOP_LEVEL_BINDING)
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
      process_commands(val, eval_string)
      
      break eval_string if valid_expression?(eval_string)
    end
  end
  
  def self.process_commands(val, eval_string)
    case val
    when "exit", "quit"
      exit
    when "!"
      eval_string.replace("")
      puts "Refreshed REPL."
    when "#pop"
      puts "Popping up a context."
      throw(:pop, :return)
    end
  end

  def self.prompt(eval_string, target)
    context = target.eval('self')
    
    if eval_string.empty?
      DEFAULT_PROMPT.call(context)
    else
      DEFAULT_WAIT_PROMPT.call(context)
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
