class Pry
  DEFAULT_PROMPT = proc do |v, nest|
    if nest == 0
      "pry(#{Pry.view(v)})> "
    else
      "pry(#{Pry.view(v)}):#{Pry.view(nest)}> "
    end
  end
  
  WAIT_PROMPT = proc do |v, nest|
    if nest == 0
      "pry(#{Pry.view(v)})* "
    else
      "pry(#{Pry.view(v)}):#{Pry.view(nest)}* "
    end
  end

  SIMPLE_PROMPT = proc { "pry> " }
  SIMPLE_WAIT = proc { "pry* " }
end
