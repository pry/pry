class Pry
  class Command::AliasPrompt < Pry::ClassCommand
    match "alias-prompt"
    group 'Prompts'
    description "Create an alias for a prompt visible in 'list-prompts'."
    banner <<-BANNER
    alias-prompt PROMPT_NAME ALIAS_PROMPT

    Create an alias for a prompt. See list-prompts for a complete list of available
    prompts.
    BANNER

    command_options argument_required: true

    def process(prompt_name, alias_name)
      if not args_ok?([prompt_name, alias_name])
        return output.puts help
      end
      if Pry::Prompt[prompt_name]
        Pry::Prompt.alias_prompt prompt_name, alias_name
        output.puts "Alias '#{alias_name}' created"
      else
        raise Pry::CommandError, "prompt #{prompt_name} cannot be aliased because it doesn't exist."
      end
    end

    private
    def args_ok?(args)
      args.size == 2 and args.all?{|s| String === s}
    end
    Pry::Commands.add_command(self)
  end
end
