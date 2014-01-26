module Pry::Config::Behavior
  ASSIGNMENT = "=".freeze
  NODUP = [TrueClass, FalseClass, NilClass, Module, Proc, Numeric].freeze
  DIRTY_MAP = {nil => []}

  def initialize(default = Pry.config)
    @default = default
    @lookup = {}
    DIRTY_MAP[self] = []
  end

  def [](key)
    @lookup[key.to_s]
  end

  def []=(key, value)
    @lookup[key.to_s] = value
  end

  def method_missing(name, *args, &block)
    key = name.to_s
    if key[-1] == ASSIGNMENT
      short_key = key[0..-2]
      DIRTY_MAP[self].push(short_key)
      self[short_key] = args[0]
    elsif DIRTY_MAP[@default].include?(key)
      DIRTY_MAP[@default].delete(key)
      value = @default.public_send(name, *args, &block)
      self[key] = _dup(value)
    elsif @lookup.has_key?(key)
      self[key]
    elsif @default.respond_to?(name)
      value = @default.public_send(name, *args, &block)
      self[key] = _dup(value)
    else
      nil
    end
  end

  def merge!(other)
    raise TypeError, "cannot coerce argument to Hash" unless other.respond_to?(:to_hash)
    other = other.to_hash
    keys, values = other.keys.map(&:to_s), other.values
    @lookup.merge! Hash[keys.zip(values)]
  end

  def respond_to?(name, boolean=false)
    @lookup.has_key?(name.to_s) or @default.respond_to?(name) or super(name, boolean)
  end

  def refresh
    @lookup = {}
  end

  def to_hash
    @lookup
  end

  def to_h
    @lookup
  end

  def quiet?
    quiet
  end

private
  def _dup(value)
    if NODUP.any? { |klass| klass === value }
      value
    else
      value.dup
    end
  end
end
