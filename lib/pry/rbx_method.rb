class Pry
  module RbxMethod
    private

    def core_code
      MethodSource.source_helper(source_location)
    end

    def core_doc
      MethodSource.comment_helper(source_location)
    end
  end
end
