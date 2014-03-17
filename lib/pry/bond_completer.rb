require "bond"
module Pry::BondCompleter
  def self.call(input, options)
    Pry.current[:pry] = options[:pry]
    Bond.agent.call(input)
  end

  def self.start
    Bond.start(:eval_binding => lambda{ Pry.current[:pry] && Pry.current[:pry].current_context })
    Bond.complete(:on => /\A/) do |input|
      Pry.commands.complete(input.line,
                            :pry_instance => Pry.current[:pry],
                            :target       => Pry.current[:pry].current_context,
                            :command_set  => Pry.current[:pry].commands)
    end
    self
  end
end
