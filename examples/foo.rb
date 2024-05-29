# frozen_string_literal: true

require 'im-lost'

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
#   > Foo.create(:foo!)
#     /projects/foo.rb:25
#   > Foo.new(*)
#     /projects/foo.rb:6
#   < Foo.new(*)
#     = #<Foo:0x00000001030810c0 @value=:foo!>
#   < Foo.create(:foo!)
#     = #<Foo:0x00000001030810c0 @value=:foo!>
#   > Foo#foo(1, *[], :none, **{}, &nil)
#     /projects/foo.rb:28
#   > Foo#bar()
#     /projects/foo.rb:15
#   < Foo#bar()
#     = :bar
#   < Foo#foo(1, *[], :none, **{}, &nil)
#     = "1-none-[]-{}-bar"
#   = /projects/foo.rb:29
#     instance variables:
#     @value: "1-none-[]-{}-bar"
#   > Foo#foo(2, *[:a, :b, :c], :some, **{:name=>:value}, &nil)
#     /projects/foo.rb:31
#   > Foo#bar()
#     /projects/foo.rb:15
#   < Foo#bar()
#     = :bar
#   < Foo#foo(2, *[:a, :b, :c], :some, **{:name=>:value}, &nil)
#     = "2-some-[a,b,c]-{:name=>:value}-bar"
#   = /projects/foo.rb:32
#     instance variables:
#     @value: "2-some-[a,b,c]-{:name=>:value}-bar"
#   > Foo#foo(3, *[], nil, **{}, &#<Proc:0x00000001030aee30 /projects/foo.rb:34>)
#     /projects/foo.rb:34
#   > Foo#bar()
#     /projects/foo.rb:15
#   < Foo#bar()
#     = :bar
#   3--[]-{}-bar
#   < Foo#foo(3, *[], nil, **{}, &#<Proc:0x00000001030aee30 /projects/foo.rb:34>)
#     = nil
#   = /projects/foo.rb:35
#     instance variables:
#     @value: "3--[]-{}-bar"
