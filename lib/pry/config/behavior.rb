module Pry::Config::Behavior
  ASSIGNMENT = "=".freeze
  NODUP = [TrueClass, FalseClass, NilClass, Symbol, Numeric, Module, Proc].freeze

  module Builder
    def from_hash(hash, default = nil)
      new(default).tap do |config|
        config.merge!(hash)
      end
    end
  end

  def self.included(klass)
    unless defined?(RESERVED_KEYS)
      const_set :RESERVED_KEYS, instance_methods(false).map(&:to_s).freeze
    end
    klass.extend(Builder)
  end

  def initialize(default = Pry.config)
    if default
      @default = default.dup
      @default.default_for(self)
    end
    @default_for = nil
    @lookup = {}
  end

  #
  # @return [Pry::Config::Behavior]
  #   returns the fallback used when a key is not found locally.
  #
  def default
    @default
  end

  def [](key)
    @lookup[key.to_s]
  end

  def []=(key, value)
    key = key.to_s
    if RESERVED_KEYS.include?(key)
      raise ArgumentError, "few things are reserved by pry, but using '#{key}' as a configuration key is."
    end
    @lookup[key] = value
  end

  def method_missing(name, *args, &block)
    key = name.to_s
    if key[-1] == ASSIGNMENT
      short_key = key[0..-2]
      self[short_key] = args[0]
    elsif key?(key)
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
    other.each do |key, value|
      self[key] = value
    end
  end

  def respond_to?(name, boolean=false)
    key?(name) or @default.respond_to?(name) or super(name, boolean)
  end

  def key?(key)
    key = key.to_s
    @lookup.key?(key)
  end

  def clear
    @lookup.clear
    true
  end
  alias_method :refresh, :clear

  def forget(key)
    @lookup.delete(key.to_s)
  end

  def default_for(other)
    if @default_for
      raise RuntimeError, "self is already the default for %s" % [Pry.view_clip(@default_for, id: true)]
    else
      @default_for = other
    end
  end

  def ==(other)
    return false unless other.respond_to?(:to_hash)
    to_hash == other.to_hash
  end
  alias_method :eql?, :==

  def keys
    @lookup.keys
  end

  def to_hash
    @lookup.dup
  end
  alias_method :to_h, :to_hash

private
  def _dup(value)
    if NODUP.any? { |klass| klass === value }
      value
    else
      value.dup
    end
  end
end
