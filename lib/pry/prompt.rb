require 'set'
module Pry::Prompt
  extend self
  PROMPT_MAP = {}
  private_constant :PROMPT_MAP
  AliasError = Class.new(RuntimeError)
  PromptInfo = Struct.new(:name, :description, :proc_array, :alias_for) do
    #
    # @return [Boolean]
    #   Returns true if the prompt is an alias of another prompt.
    #
    def alias?
      alias_for != nil
    end

    def <=>(other)
      name == other.alias_for ? 1 : 0
    end

    def to_a
      proc_array
    end

    def eql?(other)
      return false if not Pry::Prompt::PromptInfo === other
      # Aliases are eql?
      [:proc_array].all? {|m|  public_send(m) == other.public_send(m) }
    end
  end

  #
  # @return [Array<PromptInfo>]
  #   Returns an Array of {PromptInfo} objects.
  #
  def all_prompts
    PROMPT_MAP.values.map{|s| s.to_a}.flatten
  end

  #
  # @param [String] prompt
  #   The name of a prompt.
  #
  # @return [Array<PromptInfo>]
  #   Returns an array of aliases for _prompt_, as {PromptInfo} objects.
  #
  def aliases_for(prompt)
    all_prompts.select{|prompt_info| prompt_info.alias_for == prompt.to_s}
  end

  #
  # @return [Array<PromptInfo>]
  #   Returns an array of all prompt aliases, as {PromptInfo} objects.
  #
  def aliased_prompts
    all_prompts.select(&:alias?)
  end

  def find_by_proc_array(proc_array)
    all_prompts.find do |prompt|
      prompt.proc_array == proc_array and prompt.alias_for.nil?
    end
  end

  #
  # Integrate a custom prompt with Pry.
  # The prompt will be visible in the output of the "list-prompts" command, and
  # it can be used with the "change-prompt"command.
  #
  # @param [String] name
  #   The name of the prompt.
  #
  # @param [String] description
  #   A short description of the prompt.
  #
  # @param [Array<Proc,Proc>] value
  #  A prompt in the form of [proc {}, proc {}].
  #
  def add_prompt(name, description, value)
    PROMPT_MAP[name.to_s] = SortedSet.new [PromptInfo.new(name.to_s, description.to_s, value, nil)]
  end

  #
  # @example
  #
  #   # .pryrc
  #   Pry.configure do |config|
  #     config.prompt = Pry::Prompt['simple'].proc_array
  #   end
  #
  # @return [PromptInfo]
  #   Returns a prompt in the form of a PromptInfo object.
  #
  def [](name)
    all_prompts.find {|prompt| prompt.name == name.to_s }
  end

  #
  # @param [String] name
  #   The name of a prompt.
  #
  # @return [Array<PromptInfo>]
  #   An array of {PromptInfo} objects.
  #
  def all(name)
    name = name.to_s
    all_prompts.select{|prompt| prompt.name == name}
  end

  #
  # Remove a prompt from Pry.
  # It will no longer be visible in the output of "list-prompts" or usable with the
  # "change-prompt" command.
  #
  # @note
  #   Aliases are also removed.
  #
  # @param [String] name
  #   The name of a prompt.
  #
  # @return [Object, nil]
  #   Returns truthy if a prompt was deleted, otherwise nil.
  #
  def remove_prompt(name)
    prompt = self[name.to_s]
    PROMPT_MAP.delete name.to_s if prompt
  end

  #
  # Provide alternative name for a prompt, which can be used from the list-prompts
  # and change-prompt commands.
  #
  # @param [String] prompt_name
  #   The name of the prompt to alias.
  #
  # @param [String] aliased_prompt
  #   The name of the aliased prompt.
  #
  def alias_prompt(prompt_name, aliased_prompt)
    prompt_name = prompt_name.to_s
    prompt = self[prompt_name]
    if not prompt
      raise AliasError, "prompt '#{prompt}' cannot be aliased because it doesn't exist"
    elsif prompt.alias?
      prompt_name = prompt.alias_for
    end
    PROMPT_MAP[prompt_name].add PromptInfo.new *[aliased_prompt.to_s, prompt.description,
                                                 prompt.proc_array, prompt_name]
  end

  add_prompt "default",
             "The default Pry prompt. Includes information about the\n" \
             "current expression number, evaluation context, and nesting\n" \
             "level, plus a reminder that you're using Pry.",
             Pry::DEFAULT_PROMPT

  add_prompt "nav",
             "A prompt that displays the binding stack as a path and\n" \
             "includes information about _in_ and _out_.",
             Pry::NAV_PROMPT

  add_prompt "simple", "A simple '>>'.", Pry::SIMPLE_PROMPT
  add_prompt "none", "Wave goodbye to the Pry prompt.", Pry::NO_PROMPT
end
