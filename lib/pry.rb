require 'rubygems'
require 'readline'
require 'ruby_parser'

class RubyParser
  def self.valid?(code)
    new.parse(code)
  rescue Racc::ParseError
    false
  else
    true
  end
end

def pry(target)
  eval_string = ""
  while true
    prompt = ""
    if eval_string.empty?
      prompt = "> "
    else
      prompt = "* "
    end
    
    val = Readline.readline(prompt, true)
    eval_string += val

    if val == "!"
      eval_string = ""
      puts "refreshing REPL state"
      break
    end

    exit if val == "quit"
    break if RubyParser.valid?(eval_string)
  end
  begin
    puts "=> #{target.instance_eval(eval_string).inspect}"
  rescue StandardError => e
    puts "#{e.message}"
  end
end
