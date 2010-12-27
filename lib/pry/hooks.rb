class Pry
  DEFAULT_HOOKS = {
    :before_session => proc { |out, obj| out.puts "Beginning Pry session for #{Pry.view(obj)}" },
    :after_session => proc { |out, obj| out.puts "Ending Pry session for #{Pry.view(obj)}" }
  }
end
