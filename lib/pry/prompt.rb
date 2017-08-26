module Pry::Prompt
  extend self
  PROMPT_MAP = {}

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
    PROMPT_MAP[name.to_s] = {
      value: value,
      description: description
    }
  end

  #
  # @example
  #
  #   # .pryrc
  #   Pry.config.prompt = Pry::Prompt.get_prompt('simple')
  #
  # @return [Array<Proc,Proc>]
  #   Returns a prompt in the form of [proc{}, proc{}]
  #
  def get_prompt(name)
    PROMPT_MAP.key?(name.to_s) and PROMPT_MAP[name.to_s][:value]
  end

  #
  # Remove a prompt from Pry.
  # It will no longer be visible in the output of "list-prompts" or usable with the
  # "change-prompt" command.
  #
  # @param [String] name
  #   The name of a prompt.
  #
  # @return [Object, nil]
  #   Returns truthy if a prompt was deleted, otherwise nil.
  #
  def remove_prompt(name)
    PROMPT_MAP.delete name.to_s if PROMPT_MAP.key?(name.to_s)
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
