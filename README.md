# ImLost ![version](https://img.shields.io/gem/v/im-lost?label=)

If you have overlooked something again and don't really understand what your code is doing. If you have to maintain this application but can't really find your way around and certainly can't track down that stupid error. If you feel lost in all that code, here's the gem to help you out!

ImLost helps you by analyzing function calls of objects, informing you about exceptions and logging your way through your code. In short, ImLost is your debugging helper!

- Gem: [rubygems.org](https://rubygems.org/gems/im-lost)
- Source: [github.com](https://github.com/mblumtritt/im-lost)
- Help: [rubydoc.info](https://rubydoc.info/gems/im-lost/ImLost)

## Description

If you like to undertsand method call details you get a call trace with `ImLost.trace`:

```ruby
File.open('test.txt', 'w') do |file|
  ImLost.trace(file) do
    file << 'hello '
    file.puts(:world!)
  end
end
# output will look like
#   > IO#<<(?)
#     /projects/test.rb:1
#   > IO#write(*)
#     /projects/test.rb:1
#   > IO#puts(*)
#     /projects/test.rb:2
#   > IO#write(*)
#     /projects/test.rb:2
```

When you need to know if exceptions are raised and handled you can use `ImLost.trace_exceptions`:

```ruby
ImLost.trace_exceptions do
  File.write('/', 'test')
rescue SystemCallError
  raise('something went wrong!')
end
# output will look like
#   x Errno::EEXIST: File exists @ rb_sysopen - /
#   /projects/test.rb:2
#   ! Errno::EEXIST: File exists @ rb_sysopen - /
#   /projects/test.rb:3
#   x RuntimeError: something went wrong!
#   /projects/test.rb:4
```

When you like to know if and when a code point is reached, `ImLost.here` will help:

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
#  > Foo.create(:foo!)
#    /projects/foo.rb25
#  > Foo.new(*)
#    /projects/foo.rb6
#  < Foo.new(*)
#    = #<Foo:0x0000000100ab1188 @value=:foo!>
#  < Foo.create(:foo!)
#    = #<Foo:0x0000000100ab1188 @value=:foo!>
#  > Foo#foo(1, *[], :none, **{}, &nil)
#    /projects/foo.rb28
#  > Foo#bar()
#    /projects/foo.rb15
#  < Foo#bar()
#    = :bar
#  < Foo#foo(1, *[], :none, **{}, &nil)
#    = "1-none-[]-{}-bar"
#  = /projects/foo.rb29
#    instance variables:
#    @value: "1-none-[]-{}-bar"
#  = /projects/foo.rb32
#    instance variables:
#    @value: "2-some-[a,b,c]-{:name=>:value}-bar"
#  = /projects/foo.rb35
#    instance variables:
#    @value: "3--[]-{}-bar"
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
