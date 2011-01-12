class Pry

  class CommandBase
    class << self
      attr_accessor :commands
      attr_accessor :command_info
    end

    class Command
      Elements = [:name, :describe, :pattern, :action]
      
      Elements.each do |e|
        define_method(e) { |s| instance_variable_set("@#{e}", s) }
        define_method("get_#{e}") { instance_variable_get("@#{e}") }
      end

      # define action here since it needs to take a block
      def action(&block)
        @action = block
      end
    end

    def self.check_command(c)
      c.pattern(c.get_name) if !c.get_pattern
      c.describe "No description." if !c.get_describe
      
      Command::Elements.each do |e|
        raise "command has no #{e}!" if !c.send("get_#{e}")
      end
    end
    
    def self.command(name, &block)
      @commands ||= {}
      @command_info ||= {}

      c = Command.new
      c.name name

      c.instance_eval(&block)
      
      check_command(c)

      @commands.merge! c.get_pattern => c.get_action
      @command_info.merge! c.get_name => c.get_describe
    end

    command "help" do
      pattern /^help\s*(.+)?/
      describe "This menu."

      action do |opts|
        out = opts[:output]
        command_info = opts[:command_info]
        param = opts[:captures].first

        if !param
          out.puts "Command list:"
          out.puts "--"
          command_info.each do |k, v|
            puts "#{Array(k).first}".ljust(18) + v
          end
        else
          key = command_info.keys.find { |v| Array(v).any? { |k| k === param } }
          if key
            out.puts command_info[key]
          else
            out.puts "No info for command: #{param}"
          end
        end

        opts[:val].clear
      end
    end    

    def self.inherited(klass)
      klass.commands = @commands.dup
      klass.command_info = @command_info.dup
    end
  end
end
