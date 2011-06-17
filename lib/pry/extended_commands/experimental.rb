class Pry
  module ExtendedCommands

    Experimental = Pry::CommandSet.new do

      command "reload-method", "Reload the source specifically for a method", :requires_gem => "method_reload" do |meth_name|
        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        meth.reload
      end

      command "blame", "Show blame for a method", :requires_gem => "grit" do |meth_name|
        require 'grit'
        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        repo ||= Grit::Repo.new(".")
        start_line = meth.source_location.last
        num_lines = meth.source.lines.count
        authors = repo.blame(meth.source_location.first).lines.select do |v|
          v.lineno >= start_line && v.lineno <= start_line + num_lines
        end.map do |v|
          v.commit.author.output(Time.new).split(/</).first.strip
        end

        lines_with_blame = []
        meth.source.lines.zip(authors) { |line, author| lines_with_blame << ("#{author}".ljust(10) + colorize_code(line)) }
        output.puts        lines_with_blame.join
      end

    end
  end
end
