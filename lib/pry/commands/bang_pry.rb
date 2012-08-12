class Pry
  Pry::Commands.create_command "!pry" do
    group 'Navigating Pry'
    description "Start a Pry session on current self; this even works mid " \
      "multi-line expression."

    def process
      target.pry
    end
  end
end
