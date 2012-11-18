                                    # []
class A                             # ["class A"]
  def a; end                        # ["class A"]
  class B; def b; end; end          # ["class A", "class B"]
end                                 # []
                                    # []
class << A                          # ["class << A"]
  class B                           # ["class << A", "class B"]
    def c; end                      # ["class << A", "class B"]
  end                               # ["class << A"]
                                    # ["class << A"]
  module F::B                       # ["class << A", "module F::B"]
    def foo; end                    # ["class << A", "module F::B"]
  end                               # ["class << A"]
end                                 # []
                                    # []
module (:symbol.class)::Exciting    #
  def foo; end                      #
  class B                           #
    def goo; end                    #
  end                               #
end                                 # []
                                    # []
module C                            # ["module C"]
  class D                           # ["module C", "class D"]
    def guh; foo.end; end           # ["module C", "class D"]
  end                               # ["module C"]
  def bar; :end; end                # ["module C"]
  class << new.bar; end             # ["module C"]
  class << new.bar; def f; end; end #
                                    # ["module C"]
  class << self; def mug; end; end  # ["module C", "class << self"]
end                                 # []
