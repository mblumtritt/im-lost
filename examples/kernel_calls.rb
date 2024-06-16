# frozen_string_literal: true

puts <<~INFO

  This example traces calls for very basic Ruby objects when a new Class is
  generated and pretty_print is automatically loaded.

INFO

require 'im-lost'

ImLost.trace(Kernel, Object, Module, Class, self) do
  puts '=' * 79
  pp Class.new
  puts '=' * 79
end
