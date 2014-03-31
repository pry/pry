class Pry::Prompt
  MAP = {
    "default" => {
      value: Pry::DEFAULT_PROMPT,
      description: "the default pry prompt"
    },

    "simple" => {
      value: Pry::SIMPLE_PROMPT,
      description: "a simple prompt"
    },

    "nav" => {
      value: Pry::NAV_PROMPT,
      description: "a prompt that draws the binding stack as a path and includes information about _in_ and _out_"
    },

    "none" => {
      value: Pry::NO_PROMPT,
      description: "wave goodbye to the pry prompt"
    }
 }
end
