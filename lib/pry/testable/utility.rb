module Pry::Testable::Utility
  #
  # @param [String] name
  #   The name of a variable.
  #
  # @param [String] value
  #   Its value.
  #
  # @return [void]
  #
  def inject_var(name, value, b)
    Pry.current[:pry_local] = value
    b.eval("#{name} = ::Pry.current[:pry_local]")
  ensure
    Pry.current[:pry_local] = nil
  end

  #
  # @example
  #   constant_scope(:Bar) do
  #     Bar = Class.new(RuntimeError)
  #   end
  #   Bar # => NameError
  #
  # @param [Array<Symbol>] *names
  #   An array of constant names that shouldn't exist while
  #   block is yielding, and after the block has yielded.
  #
  # @return [void]
  #
  def constant_scope(*names)
    names.each do |name|
      Object.remove_const name if Object.const_defined?(name)
    end
    yield
  ensure
    names.each do |name|
      Object.remove_const name if Object.const_defined?(name)
    end
  end

  #
  # Creates a Tempfile then unlinks it after the block has yielded.
  #
  # @yieldparam [String] file
  #   The path of the temp file
  #
  def temp_file(ext='.rb')
    file = Tempfile.open(['pry', ext])
    yield file
  ensure
    file.close(true) if file
  end

  def unindent(*args)
    Pry::Helpers::CommandHelpers.unindent(*args)
  end

  def inner_scope
    catch(:inner_scope) do
      yield ->{ throw(:inner_scope, self) }
    end
  end
end
