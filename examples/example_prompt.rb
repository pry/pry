require File.expand_path(File.join(File.dirname(__FILE__), 'helper'))

# Remember, first prompt in array is the main prompt, second is the wait
# prompt (used for multiline input when more input is required)
my_prompt = [ proc { |obj, *| "inside #{obj}> " },
           proc { |obj, *| "inside #{obj}* "} ]

# Start a Pry session using the prompt defined in my_prompt
Pry.start(TOPLEVEL_BINDING, :prompt => my_prompt)
