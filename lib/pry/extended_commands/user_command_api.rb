class Pry
  module ExtendedCommands

    UserCommandAPI = Pry::CommandSet.new do

      command "define-command", "Define a command in the session, use same syntax as `command` method for command API" do |arg|
        if arg.nil?
          raise CommandError, "Provide an arg!"
        end

        prime_string = "command #{arg_string}\n"
        command_string = _pry_.r(target, prime_string)

        eval_string.replace <<-HERE
          _pry_.commands.instance_eval do
            #{command_string}
          end
        HERE

      end

      command_class "reload-command", "Reload a Pry command." do
        banner <<-BANNER
          Usage: reload-command command
          Reload a Pry command.
        BANNER

        def process
          command = _pry_.commands.find_command(args.first)

          if command.nil?
            raise Pry::CommandError, 'No command found.'
          end

          source_code = command.block.source
          file, lineno = command.block.source_location

          set = Pry::CommandSet.new do
            eval(source_code, binding, file, lineno)
          end

          _pry_.commands.delete(command.name)
          _pry_.commands.import(set)
        end
      end

      command_class "edit-command", "Edit a Pry command." do
        banner <<-BANNER
          Usage: edit-command [options] command
          Edit a Pry command.
        BANNER

        def initialize env
          @pry = env[:pry_instance]
          @command = nil
          super(env)
        end

        def options(opt)
          opt.on :p, :patch, 'Perform a in-memory edit of a command'
        end

        def process
          @command = @pry.commands.find_command(args.first)

          if @command.nil?
            raise Pry::CommandError, 'Command not found.'
          end

          case
          when opts.present?(:patch)
            edit_temporarily
          else
            edit_permanently
          end
        end

        def edit_permanently
          file, lineno = @command.block.source_location
          invoke_editor(file, lineno)

          command_set = silence_warnings do
            eval File.read(file), TOPLEVEL_BINDING, file, 1
          end

          unless command_set.is_a?(Pry::CommandSet)
            raise Pry::CommandError,
                  "Expected file '#{file}' to return a CommandSet"
          end

          @pry.commands.delete(@command.name)
          @pry.commands.import(command_set)
          set_file_and_dir_locals(file)
        end

        def edit_temporarily
          source_code = Pry::Method(@command.block).source
          modified_code = nil

          temp_file do |f|
            f.write(source_code)
            f.flush

            invoke_editor(f.path, 1)
            modified_code = File.read(f.path)
          end

          command_set = CommandSet.new do
            silence_warnings do
              pry = Pry.new :input => StringIO.new(modified_code)
              pry.rep(binding)
            end
          end

          @pry.commands.delete(@command.name)
          @pry.commands.import(command_set)
        end
      end

    end
  end
end
