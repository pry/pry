# used by show_source_spec.rb and show_doc_spec.rb
class TestClassForShowSource
  #doc
  def alpha
  end
end

class TestClassForShowSourceClassEval
  def alpha
  end
end

class TestClassForShowSourceInstanceEval
  def alpha
  end
end

# The first definition (find the second one in show_doc_spec.rb).
class TestClassForCandidatesOrder
  def alpha
  end
end
