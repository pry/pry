module Pry::Config::Behavior
  ASSIGNMENT     = "=".freeze
  NODUP          = [TrueClass, FalseClass, NilClass, Symbol, Numeric, Module, Proc].freeze
  INSPECT_REGEXP = /#{Regexp.escape "default=#<"}/

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
    @default = default
    @lookup = {}
  end

  #
  # @return [Pry::Config::Behavior]
  #   returns the default used if a matching value for a key isn't found in self
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
      # FIXME: refactor Pry::Hook so that it stores config on the config object,
      # so that we can use the normal strategy.
      self[key] = value.dup if key == 'hooks'
      value
    else
      nil
    end
  end

  def merge!(other)
    other = try_convert_to_hash(other)
    raise TypeError, "unable to convert argument into a Hash" unless other
    other.each do |key, value|
      self[key] = value
    end
  end

  def ==(other)
    @lookup == try_convert_to_hash(other)
  end
  alias_method :eql?, :==

  def respond_to_missing?(key, include_private=false)
    key?(key) or @default.respond_to?(key) or super(key, include_private)
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

  def keys
    @lookup.keys
  end

  def to_hash
    @lookup.dup
  end
  alias_method :to_h, :to_hash


  def inspect
    key_str = keys.map { |key| "'#{key}'" }.join(",")
    "#<#{_clip_inspect(self)} local_keys=[#{key_str}] default=#{@default.inspect}>"
  end

  def pretty_print(q)
    q.text inspect[1..-1].gsub(INSPECT_REGEXP, "default=<")
  end

private
  def _clip_inspect(obj)
    "#{obj.class}:0x%x" % obj.object_id << 1
  end

  def _dup(value)
    if NODUP.any? { |klass| klass === value }
      value
    else
      value.dup
    end
  end

  def try_convert_to_hash(obj)
    if Hash === obj
      obj
    elsif obj.respond_to?(:to_h)
      obj.to_h
    elsif obj.respond_to?(:to_hash)
      obj.to_hash
    else
      nil
    end
  end
end
