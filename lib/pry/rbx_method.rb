class Pry
  module RbxMethod
    private
    def core?
      source_file and RbxPath.is_core_path?(source_file)
    end

    def core_code
      MethodSource.source_helper(core_path_line)
    end

    def core_doc
      MethodSource.comment_helper(core_path_line)
    end

    def core_path_line
      [RbxPath.convert_path_to_full(source_file), source_line]
    end
  end
end
