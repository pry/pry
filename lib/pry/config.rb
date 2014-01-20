class Pry::Config
  require 'ostruct'
  require 'pry/config/default'
  require 'pry/config/convenience'
  ASSIGNMENT = "=".freeze

  def self.shortcuts
    Convenience::SHORTCUTS
  end

  def initialize(default = Pry.config)
    @default = default
    @lookup = {}
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
      short_key = key.to_s[0..-2]
      self[short_key] = args[0]
    elsif @lookup.has_key?(key)
      self[key]
    elsif @default.respond_to?(name)
      @default.public_send(name, *args, &block)
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
    to_hash
  end

  def quiet?
    quiet
  end
end
