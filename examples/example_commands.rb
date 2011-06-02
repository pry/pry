require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

class MathCommands < Pry::CommandBase
  command "greet", "Greet a person, e.g: greet john" do |name|
    output.puts "Good afternoon #{name.capitalize}! Do you like Math?"
  end

  command "add", "Add a list of numbers together, e.g: add 1 2 3 4" do |*args|
    output.puts "Total: #{args.map(&:to_f).inject(&:+)}"
  end

  command "multiply", "Multiply a list of numbers together, e.g: multiply 1 2 3 4" do |*args|
    output.puts "Total: #{args.map(&:to_f).inject(&:*)}"
  end

  # Explicitly giving a description of "" to prevent command being
  # displayed in 'help'
  command "exit", "" do
    throw :breakout, 0
  end

  # Bring in the "!" method from Pry::Commands
  import_from Pry::Commands, "!"
end

# Since we provide math commands, let's have mathematical
# before_session and after_session hooks, and a mathematical prompt
math_prompt = [proc { "math> " }, proc { "math* " }]
math_hooks = {
  :before_session => proc { |output, *| output.puts "Welcome! Let's do some math! Type 'help' for a list of commands." },
  :after_session => proc { |output, *| output.puts "Goodbye!" }
}

# Start a Pry session using the commands defined in MyCommands
# Type 'help' in Pry to get a list of the commands and their descriptions
Pry.start(TOPLEVEL_BINDING, :commands => MathCommands, :prompt => math_prompt, :hooks => math_hooks)
