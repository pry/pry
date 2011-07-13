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

      command "git blame", "Show blame for a method", :requires_gem => "grit" do |meth_name|
        require 'grit'
        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        file_name = meth.source_location.first
        code, start_line = method_code_from_head(meth)

        repo ||= Grit::Repo.new(".")
        num_lines = code.lines.count
        authors = repo.blame(file_name, repo.head.commit).lines.select do |v|
          v.lineno >= start_line && v.lineno <= start_line + num_lines
        end.map do |v|
          v.commit.author.output(Time.new).split(/</).first.strip
        end

        lines_with_blame = []
        code.lines.zip(authors) { |line, author| lines_with_blame << ("#{author}".ljust(10) + colorize_code(line)) }
        output.puts lines_with_blame.join
      end

      command "git diff", "Show the diff for a method", :requires_gem => ["grit", "diffy"] do |meth_name|
        require 'grit'
        require 'diffy'

        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end

        output.puts colorize_code(Diffy::Diff.new(method_code_from_head(meth).first, meth.source))
      end

      command "git add", "Add a method to index", :requires_gem => ["grit", "diffy"] do |meth_name|
        require 'grit'
        require 'tempfile'

        if (meth = get_method_object(meth_name, target, {})).nil?
          output.puts "Invalid method name: #{meth_name}."
          next
        end
        repo = Grit::Repo.new('.')

        file_name = relative_path(meth.source_location.first)
        file_data = get_file_from_commit(file_name)
        code, start_line = method_code_from_head(meth)
        end_line = start_line + code.lines.count

        before_code = file_data.lines.to_a[0..(start_line - 2)]
        after_code = file_data.lines.to_a[end_line - 1..-1]

        final_code = before_code << meth.source.lines.to_a << after_code

        t = Tempfile.new("tmp")
        t.write final_code.join
        t.close

        sha1 = `git hash-object -w #{t.path}`.chomp
        system("git update-index --cacheinfo 100644 #{sha1} #{file_name}")
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
          [Pry.new(:input => StringIO.new(code.lines.to_a[start_line..-1].join)).r(target), start_line + 1]
        end

        def relative_path(path)
          path =~ /#{Regexp.escape(File.expand_path("."))}\/(.*)/
          $1
        end

      end

    end
  end
end
