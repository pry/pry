class Pry
  module ExtendedCommands

    UserCommandAPI = Pry::CommandSet.new do

      command "define-command", "To honor Mon-Ouie" do |arg|
        next output.puts("Provide an arg!") if arg.nil?

        prime_string = "command #{opts[:arg_string]}\n"
        command_string = Pry.active_instance.r(target, prime_string)

        opts[:eval_string].replace <<-HERE
          _pry_.commands.instance_eval do
            #{command_string}
          end
        HERE

      end

    end
  end
end
