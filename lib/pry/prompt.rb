module Pry::Prompt
  extend self
  PROMPT_MAP = {}
  AliasError = Class.new(RuntimeError)
  PromptInfo = Struct.new(:name, :description, :proc_array, :alias_for) do
    #
    # @return [Boolean]
    #   Returns true if the prompt is an alias of another prompt.
    #
    def alias?
      alias_for != nil
    end
  end

  #
  # @return [Array<PromptInfo>]
  #   Returns an Array of {PromptInfo} objects.
  #
  def all_prompts
    PROMPT_MAP.values
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
    PROMPT_MAP[name.to_s] = PromptInfo.new(name, description, value, nil)
  end

  #
  # @example
  #
  #   # .pryrc
  #   Pry.config.prompt = Pry::Prompt.get_prompt('simple').proc_array
  #
  # @return [PromptInfo]
  #   Returns a prompt in the form of a PromptInfo object.
  #
  def get_prompt(name)
    PROMPT_MAP.key?(name.to_s) and PROMPT_MAP[name.to_s]
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
    name = name.to_s
    if PROMPT_MAP.key?(name)
      aliases_for(name).each{|_alias| PROMPT_MAP.delete(_alias.name)}
      PROMPT_MAP.delete name
    end
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
    prompt = get_prompt(prompt_name)
    if not prompt
      raise AliasError, "prompt '#{prompt}' cannot be aliased because it doesn't exist"
    elsif prompt.alias?
      prompt_name = prompt.alias_for
    end
    PROMPT_MAP[aliased_prompt] = PromptInfo.new *[aliased_prompt, prompt.description,
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
