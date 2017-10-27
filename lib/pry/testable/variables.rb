module Pry::Testable::Variables
  #
  # @example
  #   temporary_constants(:Foo, :Bar) do
  #     Foo = Class.new(RuntimeError)
  #     Bar = Class.new(RuntimeError)
  #   end
  #   Foo # => NameError
  #   Bar # => NameError
  #
  # @param [Array<Symbol>] *names
  #   An array of constant names that be defined by a block,
  #   and removed by this method afterwards.
  #
  # @return [void]
  #
  def temporary_constants(*names)
    names.each do |name|
      Object.remove_const name if Object.const_defined?(name)
    end
    yield
  ensure
    names.each do |name|
      Object.remove_const name if Object.const_defined?(name)
    end
  end
end
