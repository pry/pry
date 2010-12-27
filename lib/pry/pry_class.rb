class Pry

  # class accessors
  class << self
    attr_reader :nesting
    attr_accessor :last_result, :active_instance
    attr_accessor :input, :output
    attr_accessor :commands, :print, :hooks
    attr_accessor :default_prompt
  end
  
  def self.start(target=TOPLEVEL_BINDING, options={})
    new(options).repl(target)
  end

  def self.view(obj)
    case obj
    when String, Hash, Array, Symbol, nil
      obj.inspect
    else
      obj.to_s
    end
  end

  def self.reset_defaults
    @input = Input.new
    @output = Output.new
    @commands = Commands.new(@output)
    @default_prompt = DEFAULT_PROMPT
    @print = DEFAULT_PRINT
    @hooks = DEFAULT_HOOKS
  end

  self.reset_defaults

  @nesting = []
  def @nesting.level
    last.is_a?(Array) ? last.first : nil
  end
end
