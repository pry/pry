class Pry
  Pry::Commands.create_command "shell-mode" do
    group 'Input and Output'
    description "Toggle shell mode. Bring in pwd prompt and file completion."

    def process
      case _pry_.prompt
      when Pry::SHELL_PROMPT
        _pry_.pop_prompt
        _pry_.custom_completions = Pry::DEFAULT_CUSTOM_COMPLETIONS
      else
        _pry_.push_prompt Pry::SHELL_PROMPT
        _pry_.custom_completions = Pry::FILE_COMPLETIONS
        Readline.completion_proc = Pry::InputCompleter.build_completion_proc target,
        _pry_.instance_eval(&Pry::FILE_COMPLETIONS)
      end
    end
  end

  Pry::Commands.alias_command "file-mode", "shell-mode"
end
