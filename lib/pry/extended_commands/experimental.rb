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

      command "diff", "Show the diff for a method", :requires_gem => ["grit", "diffy"] do |meth_name|
        require 'grit'
        require 'diffy'

        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        output.puts colorize_code(Diffy::Diff.new(method_code_from_head(meth), meth.source))
      end

      helpers do
        def get_file_from_commit(path)
          repo = Grit::Repo.new('.')
          head = repo.commits.first
          tree_names = path.split("/")
          start_tree = head.tree
          blob_name = tree_names.last
          tree = tree_names[0..-2].inject(start_tree)  { |a, v|  a.trees.find { |t| t.basename == v } }
          blob = tree.blobs.find { |v| v.basename == blob_name }
          blob.data
        end

        def method_code_from_head(meth)
          code = get_file_from_commit(relative_path(meth.source_location.first))
          search_line = meth.source.lines.first.strip
          _, start_line = code.lines.to_a.each_with_index.find { |v, i| v.strip == search_line }
          start_line
          Pry.new(:input => StringIO.new(code.lines.to_a[start_line..-1].join)).r(target)
        end

        def relative_path(path)
          path =~ /#{Regexp.escape(File.expand_path("."))}\/(.*)/
          $1
        end

      end

    end
  end
end
