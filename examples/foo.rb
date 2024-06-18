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
#     /examples/foo.rb:24
#   > Foo.new(*)
#     /examples/foo.rb:6
#   < Foo.new(*)
#     /examples/foo.rb:6
#     = #<Foo:0x00000001006448c0 @value=:foo!>
#   < Foo.create(:foo!)
#     /examples/foo.rb:24
#     = #<Foo:0x00000001006448c0 @value=:foo!>
#   > Foo#foo(1, *[], :none, **{}, &nil)
#     /examples/foo.rb:27
#   > Foo#bar()
#     /examples/foo.rb:15
#   < Foo#bar()
#     /examples/foo.rb:15
#     = :bar
#   < Foo#foo(1, *[], :none, **{}, &nil)
#     /examples/foo.rb:27
#     = "1-none-[]-{}-bar"
#   * /examples/foo.rb:28
#     > instance variables
#       @value: "1-none-[]-{}-bar"
#   > Foo#foo(2, *[:a, :b, :c], :some, **{:name=>:value}, &nil)
#     /examples/foo.rb:30
#   > Foo#bar()
#     /examples/foo.rb:15
#   < Foo#bar()
#     /examples/foo.rb:15
#     = :bar
#   < Foo#foo(2, *[:a, :b, :c], :some, **{:name=>:value}, &nil)
#     /examples/foo.rb:30
#     = "2-some-[a,b,c]-{:name=>:value}-bar"
#   * /examples/foo.rb:31
#     > instance variables
#       @value: "2-some-[a,b,c]-{:name=>:value}-bar"
#   > Foo#foo(3, *[], nil, **{}, &#<Proc:0x0000000100641d28 /examples/foo.rb:33>)
#     /examples/foo.rb:33
#   > Foo#bar()
#     /examples/foo.rb:15
#   < Foo#bar()
#     /examples/foo.rb:15
#     = :bar
#   3--[]-{}-bar
#   < Foo#foo(3, *[], nil, **{}, &#<Proc:0x0000000100641d28 /examples/foo.rb:33>)
#     /examples/foo.rb:33
#     = nil
#   * /examples/foo.rb:34
#     > instance variables
#       @value: "3--[]-{}-bar"
