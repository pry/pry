class Pry
  module RbxMethod
    private
    def core?
      source_file and is_core_path?(source_file)
    end

    def core_code
      MethodSource.source_helper(core_path_line)
    end

    def core_doc
      MethodSource.comment_helper(core_path_line)
    end

    def core_path_line
      [convert_path_to_full(source_file), source_line]
    end

    def is_core_path?(path)
      path.start_with?("kernel")
    end

    def rvm_ruby?(path)
      !!(path =~ /\.rvm/)
    end

    def convert_path_to_full(path)
      if rvm_ruby?(Rubinius::BIN_PATH)
        rvm_convert_path_to_full(path)
      else
        std_convert_path_to_full(path)
      end
    end

    def rvm_convert_path_to_full(path)
      ruby_name = File.dirname(Rubinius::BIN_PATH).split("/").last
      source_path = File.join(File.dirname(File.dirname(File.dirname(Rubinius::BIN_PATH))),  "src", ruby_name)
      file_name = File.join(source_path, path)
      raise "Cannot find rbx core source" if !File.exists?(file_name)
      file_name
    end

    def std_convert_path_to_full(path)
      file_name = File.join(Rubinius::BIN_PATH, "..", path)
      raise "Cannot find rbx core source" if !File.exists?(file_name)
      file_name
    end
  end
end
