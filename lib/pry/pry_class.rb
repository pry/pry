class Pry

  # class accessors
  class << self
    attr_reader :nesting
    attr_accessor :last_result
    attr_accessor :input, :output
    attr_accessor :commands
    attr_accessor :default_prompt, :wait_prompt
  end
  
  def self.start(target=TOPLEVEL_BINDING, options={})
    new(options).repl(target)
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
    self.commands = COMMANDS
    self.default_prompt = DEFAULT_PROMPT
    self.wait_prompt = WAIT_PROMPT
  end

  self.reset_defaults

  @nesting = []

  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end
end
