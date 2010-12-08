require 'rubygems'
require 'readline'
require 'ruby_parser'

module Pry
  module RubyParserExtension
    def valid?(code)
      new.parse(code)
    rescue Racc::ParseError
      false
    else
      true
    end
  end

  def self.repl_loop(target=TOPLEVEL_BINDING)
    repl(target, :loop => true)
  end

  def self.repl(target=TOPLEVEL_BINDING, options={:loop => false})
    prompt = ""
    code = proc do
      eval_string = ""
      while true
        if eval_string.empty?
          prompt = "> "
        else
          prompt = "* "
        end
        
        val = Readline.readline(prompt, true)
        eval_string += "#{val}\n"

        if val == "#"
        elsif val == "#pop"
          puts "Poppping back"
          return
        elsif (_, new_target = val.split(/#target\s*\=\s*/)).size > 1
          target = target.eval(new_target)
          eval_string = ""
          puts "Context changed to #{target}"
          break
        end

        abort if val == "abort"
        exit if val == "exit"
        exit if val == "quit"
        
        break if RubyParser.valid?(eval_string)
      end
      begin
        puts "=> #{target.eval(eval_string).inspect}"
      rescue StandardError => e
        puts "#{e.message}"
      end
    end

    if options[:loop]
      loop(&code)
    else
      code.call
    end
  end
end

class RubyParser
  extend Pry::RubyParserExtension
end
