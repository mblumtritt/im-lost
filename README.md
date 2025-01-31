# ImLost ![version](https://img.shields.io/gem/v/im-lost?label=)

If you have overlooked something again and don't really understand what your code is doing. If you have to maintain this application but can't really find your way around and certainly can't track down that stupid error. If you feel lost in all that code, here's the gem to help you out!

ImLost helps you by analyzing function calls of objects, informing you about exceptions and logging your way through your code. In short, ImLost is your debugging helper!

- Gem: [rubygems.org](https://rubygems.org/gems/im-lost)
- Source: [github.com](https://github.com/mblumtritt/im-lost)
- Help: [rubydoc.info](https://rubydoc.info/gems/im-lost/ImLost)

## Description

If you like to understand method call details you get a call trace with `ImLost.trace`:

```ruby
File.open('test.txt', 'w') do |file|
  ImLost.trace(file) do
    file << 'hello '
    file.puts(:world!)
  end
end

# output will look like
#  > IO#<<(?)
#    /examples/test.rb:1
#  > IO#write(*)
#    /examples/test.rb:1
#  > IO#puts(*)
#    /examples/test.rb:2
#  > IO#write(*)
#    /examples/test.rb:2
```

When you need to know if exceptions are raised and handled you can use `ImLost.trace_exceptions`:

```ruby
ImLost.trace_exceptions do
  File.write('/', 'test')
rescue SystemCallError
  raise('something went wrong!')
end

# output will look like
#  x Errno::EEXIST: File exists @ rb_sysopen - /
#    /examples/test.rb:2
#  ! Errno::EEXIST: File exists @ rb_sysopen - /
#    /examples/test.rb:3
#  x RuntimeError: something went wrong!
#    /examples/test.rb:4
```

When you like to know if a code point is reached, `ImLost.here` will help:

```ruby
ImLost.here
```

If you like to know the instance variables values of an object, use
`ImLost.vars`:

```ruby
ImLost.vars(self)
```

Or you can print the current local variables:

```ruby
ImLost.vars(binding)
```

See the [online help](https://rubydoc.info/gems/im-lost/ImLost) for more!

## Example

```ruby
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
#  > Foo.create(:foo!)
#    ./examples/foo.rb:24
#  > Foo.new(*args)
#    ./examples/foo.rb:6
#  < Foo.new(*args)
#    ./examples/foo.rb:6
#    = #<Foo:0x0000000104c24b88 @value=:foo!>
#  < Foo.create(:foo!)
#    ./examples/foo.rb:24
#    = #<Foo:0x0000000104c24b88 @value=:foo!>
#  > Foo#foo(1, *[], :none, **{}, &nil)
#    ./examples/foo.rb:27
#  > Foo#bar()
#    ./examples/foo.rb:15
#  < Foo#bar()
#    ./examples/foo.rb:15
#    = :bar
#  < Foo#foo(1, *[], :none, **{}, &nil)
#    ./examples/foo.rb:27
#    = "1-none-[]-{}-bar"
#  * ./examples/foo.rb:28
#    > instance variables
#      @value: "1-none-[]-{}-bar"
#  > Foo#foo(2, *[:a, :b, :c], :some, **{name: :value}, &nil)
#    ./examples/foo.rb:30
#  > Foo#bar()
#    ./examples/foo.rb:15
#  < Foo#bar()
#    ./examples/foo.rb:15
#    = :bar
#  < Foo#foo(2, *[:a, :b, :c], :some, **{name: :value}, &nil)
#    ./examples/foo.rb:30
#    = "2-some-[a,b,c]-{name: :value}-bar"
#  * ./examples/foo.rb:31
#    > instance variables
#      @value: "2-some-[a,b,c]-{name: :value}-bar"
#  > Foo#foo(3, *[], nil, **{}, &#<Proc:0x0000000104c22180 ./examples/foo.rb:33>)
#    ./examples/foo.rb:33
#  > Foo#bar()
#    ./examples/foo.rb:15
#  < Foo#bar()
#    ./examples/foo.rb:15
#    = :bar
#  3--[]-{}-bar
#  < Foo#foo(3, *[], nil, **{}, &#<Proc:0x0000000104c22180 ./examples/foo.rb:33>)
#    ./examples/foo.rb:33
#    = nil
#  * ./examples/foo.rb:34
#    > instance variables
#      @value: "3--[]-{}-bar"
```

See [examples dir](./examples) for more…

## Installation

You can install the gem in your system with

```shell
gem install im-lost
```

or you can use [Bundler](http://gembundler.com/) to add ImLost to your own project:

```shell
bundle add im-lost
```

After that you only need one line of code to have everything together

```ruby
require 'im-lost'
```
