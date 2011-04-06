class Pry

  # This proc will be instance_eval's against the active Pry instance
  DEFAULT_CUSTOM_COMPLETIONS = proc { commands.commands.keys }
  FILE_COMPLETIONS = proc { commands.commands.keys + Dir.entries('.') }
end
