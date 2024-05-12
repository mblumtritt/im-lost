# frozen_string_literal: true

require_relative '../lib/im-lost'

class Foo
  def self.create(value:) = new(value)

  attr_reader :value

  def initialize(value)
    @value = value
  end

  def foo(arg, *args, key: nil, **kw_args, &block)
    @value = "#{arg}-#{key}-[#{args.join(',')}]-#{kw_args.inspect}-#{bar}"
    block ? block.call(@value) : @value
  end

  def bar = :bar
end

ImLost.trace_results = true
ImLost.trace(Foo)

my_foo = Foo.create(value: :foo!)
ImLost.trace(my_foo)

my_foo.foo(1, key: :none)
ImLost.vars(my_foo)

my_foo.foo(2, :a, :b, :c, key: :some, name: :value)
ImLost.vars(my_foo)

my_foo.foo(3) { puts _1 }
ImLost.vars(my_foo)

# output will look like
# > Foo.create(:foo!)
#   /projects/foo.rb25
# > Foo.new(*)
#   /projects/foo.rb6
# < Foo.new(*)
#   = #<Foo:0x0000000100ab1188 @value=:foo!>
# < Foo.create(:foo!)
#   = #<Foo:0x0000000100ab1188 @value=:foo!>
# > Foo#foo(1, *[], :none, **{}, &nil)
#   /projects/foo.rb28
# > Foo#bar()
#   /projects/foo.rb15
# < Foo#bar()
#   = :bar
# < Foo#foo(1, *[], :none, **{}, &nil)
#   = "1-none-[]-{}-bar"
# = /projects/foo.rb29
#   instance variables:
#   @value: "1-none-[]-{}-bar"
# = /projects/foo.rb32
#   instance variables:
#   @value: "2-some-[a,b,c]-{:name=>:value}-bar"
# = /projects/foo.rb35
#   instance variables:
#   @value: "3--[]-{}-bar"
