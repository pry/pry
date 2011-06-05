require 'rubygems'
unless Object.const_defined? 'Pry'
  $:.unshift File.expand_path '../../lib', __FILE__
  require 'pry'
end

