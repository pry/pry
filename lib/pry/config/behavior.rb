module Pry::Config::Behavior
  ASSIGNMENT = "=".freeze
  NODUP = [TrueClass, FalseClass, NilClass, Module, Proc, Numeric].freeze
  RESERVED_KEYS = [
                   "[]", "[]=", "merge!",
                   "respond_to?", "key?", "refresh",
                   "forget", "inherited_by", "to_h",
                   "to_hash"
                  ].freeze

  def initialize(default = Pry.config)
    @default = default.dup if default
    @default.inherited_by(self) if default
    @writes = {}
    @reads = {}
  end

  def [](key)
    lookup = @reads.merge(@writes)
    lookup[key.to_s]
  end

  def []=(key, value)
    key = key.to_s
    if RESERVED_KEYS.include?(key)
      raise ArgumentError, "sorry, '#{key}' is a reserved configuration key."
    end
    @writes[key] = value
  end

  def method_missing(name, *args, &block)
    key = name.to_s
    if key[-1] == ASSIGNMENT
      short_key = key[0..-2]
      @inherited_by.forget(:read, short_key) if @inherited_by
      self[short_key] = args[0]
    elsif key?(key)
      self[key]
    elsif @default.respond_to?(name)
      value = @default.public_send(name, *args, &block)
      @reads[key] = _dup(value)
    else
      nil
    end
  end

  def merge!(other)
    raise TypeError, "cannot coerce argument to Hash" unless other.respond_to?(:to_hash)
    other = other.to_hash
    keys, values = other.keys.map(&:to_s), other.values
    @writes.merge! Hash[keys.zip(values)]
  end

  def respond_to?(name, boolean=false)
    key?(name) or @default.respond_to?(name) or super(name, boolean)
  end

  def key?(key)
    key = key.to_s
    @writes.key?(key) or @reads.key?(key)
  end

  def refresh
    @writes.clear
    @reads.clear
    true
  end

  def forget(lookup_type, key)
    case lookup_type
    when :write
      @writes.delete(key)
    when :read
      @reads.delete(key)
    else
      raise ArgumentError, "specify a lookup type (:read or :write)"
    end
  end

  def inherited_by(other)
    if @inherited_by
      raise RuntimeError, "instance of Pry::Config should be inherited by only one instance"
    else
      @inherited_by = other
    end
  end

  def to_hash
    @reads.merge(@writes)
  end
  alias_method :to_h, :to_hash

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
