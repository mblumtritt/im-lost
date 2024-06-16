# frozen_string_literal: true

class TestSample
  attr_reader :foo
  attr_accessor :bar

  def initialize
    @foo = 20
    @bar = 22
  end

  def add(arg0, arg1) = arg0 + arg1
  def add_kw(arg0:, arg1:) = arg0 + arg1
  def add_block(arg, &block) = arg + block[]
  def map(*args) = args.map(&:to_s)
  def insp(**kw_args) = kw_args.inspect
  def fwd(...) = add(...)
end

RSpec.describe ImLost do
  let(:sample) { TestSample.new }

  it 'has defined default attributes' do
    is_expected.to have_attributes(
      caller_locations: true,
      trace_calls: true,
      trace_results: true
    )
  end

  context 'trace method calls' do
    before do
      ImLost.trace_calls = true
      ImLost.caller_locations = false
      ImLost.trace_results = false
      ImLost.trace(sample)
    end

    after { ImLost.untrace_all! }

    it 'traces method calls' do
      expect { sample.foo + sample.bar }.to write <<~OUTPUT
        > TestSample#foo()
        > TestSample#bar()
      OUTPUT
    end

    it 'includes arguments in call signatures' do
      expect { sample.add(21, 21) }.to write "> TestSample#add(21, 21)\n"
    end

    it 'includes keyword arguments in call signatures' do
      expect { sample.add_kw(arg0: 21, arg1: 21) }.to write(
        "> TestSample#add_kw(21, 21)\n"
      )
    end

    it 'includes block arguments in call signatures' do
      block = proc { 22 }
      expect { sample.add_block(20, &block) }.to write(
        "> TestSample#add_block(20, &#{block.inspect})\n"
      )
    end

    it 'includes splat arguments' do
      expect { sample.map(1, 2, 3, 4) }.to write(
        "> TestSample#map(*[1, 2, 3, 4])\n"
      )
    end

    it 'includes empty splat arguments' do
      expect { sample.map }.to write "> TestSample#map(*[])\n"
    end

    it 'includes keyword splat arguments' do
      expect { sample.insp(a: 1, b: 2) }.to write(
        "> TestSample#insp(**{:a=>1, :b=>2})\n"
      )
    end

    it 'includes empty keyword splat arguments' do
      expect { sample.insp }.to write "> TestSample#insp(**{})\n"
    end

    it 'handles argument forwarding' do
      expected =
        if RUBY_VERSION.to_f < 3.1
          <<~OUTPUT
            > TestSample#fwd(*, &)
            > TestSample#add(40, 2)
          OUTPUT
        else
          <<~OUTPUT
            > TestSample#fwd(*, **, &)
            > TestSample#add(40, 2)
          OUTPUT
        end

      expect { sample.fwd(40, 2) }.to write expected
    end

    it 'can check if an object is traced' do
      expect(ImLost.traced?(sample)).to be true
      expect(ImLost.untrace(sample)).to be sample
      expect(ImLost.traced?(sample)).to be false
      expect(ImLost.traced?(BasicObject.new)).to be false
    end

    it 'can trace temporary' do
      another = TestSample.new

      expect do
        another.map
        ImLost.trace(another) { |obj| obj.add(20, 22) }
        another.map
      end.to write "> TestSample#add(20, 22)\n"
    end

    it 'can include caller locations' do
      ImLost.caller_locations = true

      expect { sample.foo }.to write <<~OUTPUT
        > TestSample#foo()
          #{__FILE__}:#{__LINE__ - 2}
      OUTPUT
    end
  end

  context 'trace method results' do
    before do
      ImLost.trace_calls = false
      ImLost.caller_locations = false
      ImLost.trace_results = true
      ImLost.trace(sample)
    end

    after { ImLost.untrace_all! }

    it 'traces method call results' do
      expect { sample.foo + sample.bar }.to write <<~OUTPUT
        < TestSample#foo()
          = 20
        < TestSample#bar()
          = 22
      OUTPUT
    end

    it 'includes arguments in call signatures' do
      expect { sample.add(21, 21) }.to write(
        "< TestSample#add(21, 21)\n  = 42\n"
      )
    end

    it 'includes block arguments in call signatures' do
      block = proc { 20 }

      expect { sample.add_block(22, &block) }.to write <<~OUTPUT
        < TestSample#add_block(22, &#{block.inspect})
          = 42
      OUTPUT
    end

    it 'includes splat arguments' do
      expect { sample.map(1, 2, 3, 4) }.to write <<~OUTPUT
        < TestSample#map(*[1, 2, 3, 4])
          = ["1", "2", "3", "4"]
      OUTPUT
    end

    it 'includes empty splat arguments' do
      expect { sample.map }.to write "< TestSample#map(*[])\n  = []\n"
    end

    it 'includes keyword splat arguments' do
      expect { sample.insp(a: 1, b: 2) }.to write <<~OUTPUT
        < TestSample#insp(**{:a=>1, :b=>2})
          = "{:a=>1, :b=>2}"
      OUTPUT
    end

    it 'includes empty keyword splat arguments' do
      expect { sample.insp }.to write "< TestSample#insp(**{})\n  = \"{}\"\n"
    end

    it 'handles argument forwarding' do
      expected =
        if RUBY_VERSION.to_f < 3.1
          <<~OUTPUT
            < TestSample#add(40, 2)
              = 42
            < TestSample#fwd(*, &)
              = 42
          OUTPUT
        else
          <<~OUTPUT
            < TestSample#add(40, 2)
              = 42
            < TestSample#fwd(*, **, &)
              = 42
          OUTPUT
        end

      expect { sample.fwd(40, 2) }.to write expected
    end

    it 'can trace temporary' do
      another = TestSample.new

      expect do
        another.map
        ImLost.trace(another) { |obj| obj.add(20, 22) }
        another.map
      end.to write "< TestSample#add(20, 22)\n  = 42\n"
    end
  end

  context '.trace_exceptions' do
    it 'traces exceptions and rescue blocks' do
      if RUBY_VERSION.to_f < 3.3
        expect do
          ImLost.trace_exceptions do
            raise(ArgumentError, 'not the answer - 21')
          rescue ArgumentError
            # nop
          end
        end.to write <<~OUTPUT
          x ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 6}
        OUTPUT
      else
        expect do
          ImLost.trace_exceptions do
            raise(ArgumentError, 'not the answer - 21')
          rescue ArgumentError
            # nop
          end
        end.to write <<~OUTPUT
          x ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 6}
          ! ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 7}
        OUTPUT
      end
    end

    it 'allows to disable location information' do
      expected =
        if RUBY_VERSION.to_f < 3.3
          "x ArgumentError: not the answer - 21\n"
        else
          <<~OUTPUT
            x ArgumentError: not the answer - 21
            ! ArgumentError: not the answer - 21
          OUTPUT
        end

      expect do
        ImLost.trace_exceptions(with_locations: false) do
          raise(ArgumentError, 'not the answer - 21')
        rescue ArgumentError
          # nop
        end
      end.to write expected
    end

    it 'allows to be stacked' do
      if RUBY_VERSION.to_f < 3.3
        expect do
          ImLost.trace_exceptions(with_locations: false) do
            ImLost.trace_exceptions(with_locations: true) do
              raise(ArgumentError, 'not the answer - 42')
            rescue ArgumentError
              # nop
            end
            raise(ArgumentError, 'not the answer - 21')
          rescue ArgumentError
            # nop
          end
        end.to write <<~OUTPUT
          x ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 10}
          x ArgumentError: not the answer - 21
        OUTPUT
      else
        expect do
          ImLost.trace_exceptions(with_locations: false) do
            ImLost.trace_exceptions(with_locations: true) do
              raise(ArgumentError, 'not the answer - 42')
            rescue ArgumentError
              # nop
            end
            raise(ArgumentError, 'not the answer - 21')
          rescue ArgumentError
            # nop
          end
        end.to write <<~OUTPUT
          x ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 10}
          ! ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 11}
          x ArgumentError: not the answer - 21
          ! ArgumentError: not the answer - 21
        OUTPUT
      end
    end

    if RUBY_VERSION.to_f >= 3.3
      it 'prints exception tree for rescued exceptions' do
        expect do
          ImLost.trace_exceptions(with_locations: false) do
            begin
              begin
                raise(ArgumentError, 'not the answer - 21')
              rescue ArgumentError
                raise NoMethodError
              end
            rescue NoMethodError
              raise NotImplementedError
            end
          rescue NotImplementedError
            nil
          end
        end.to write <<~OUTPUT
          x ArgumentError: not the answer - 21
          ! ArgumentError: not the answer - 21
          x NoMethodError: NoMethodError
          ! NoMethodError: NoMethodError
            [ArgumentError: not the answer - 21]
          x NotImplementedError: NotImplementedError
          ! NotImplementedError: NotImplementedError
            [NoMethodError: NoMethodError]
            [ArgumentError: not the answer - 21]
        OUTPUT
      end
    end
  end

  context 'trace locations' do
    it 'writes call location' do
      expect { ImLost.here }.to write "* #{__FILE__}:#{__LINE__}\n"
    end

    it 'writes only when given condition is truethy' do
      expect do
        ImLost.here(1 > 2)
        ImLost.here(1 < 2)
      end.to write "* #{__FILE__}:#{__LINE__ - 1}\n"
    end

    it 'returns given argument' do
      ImLost.output = StringIO.new # prevent output

      obj = Object.new
      expect(ImLost.here(obj)).to be obj
    end
  end

  context 'dump vars' do
    it 'prints instance variables' do
      expect { ImLost.vars(sample) }.to write <<~OUTPUT
        * #{__FILE__}:#{__LINE__ - 1}
          > instance variables
            @bar: 22
            @foo: 20
      OUTPUT
    end

    it 'returns given object' do
      ImLost.output = StringIO.new # prevent output

      expect(ImLost.vars(sample)).to be sample
    end

    context 'when instance variables could not be determined' do
      let(:sample) { BasicObject.new }

      it 'it prints an error message' do
        expect { ImLost.vars(sample) }.to write <<~OUTPUT
          * #{__FILE__}:#{__LINE__ - 1}
            !!! unable to retrieve vars
        OUTPUT
      end
    end

    context 'when a Binding is given' do
      it 'prints local variables' do
        expect do
          test = :foo_bar_baz
          sample = test.to_s
          ImLost.vars(binding)
        end.to write <<~OUTPUT
          * #{__FILE__}:#{__LINE__ - 2}
            > local variables
              sample: "foo_bar_baz"
              test: :foo_bar_baz
        OUTPUT
      end

      it 'returns given bindig' do
        ImLost.output = StringIO.new # prevent output

        expect(ImLost.vars(binding)).to be_a Binding
      end
    end

    context 'when a Thread is given' do
      let(:thread) do
        Thread.new do
          Thread.current[:var] = 21
          Thread.current.thread_variable_set(:result, 42)
        end
      end

      after { thread.join }

      it 'prints thread variables' do
        expect do
          thread[:var] = 41
          ImLost.vars(thread.join)
        end.to write <<~OUTPUT
          * #{__FILE__}:#{__LINE__ - 2}
            terminated Thread#{
                " #{thread.__id__}" unless defined?(thread.native_thread_id)
              }
            > fiber-local variables
              var: 21
            > thread variables
              result: 42
        OUTPUT
      end

      it 'returns given thread' do
        ImLost.output = StringIO.new # prevent output

        expect(ImLost.vars(thread)).to be thread
      end
    end

    if defined?(Fiber.current) && defined?(Fiber.current.storage)
      context 'when the current Fiber is given' do
        before do
          Fiber[:var1] = 22
          Fiber[:var2] = 20
          Fiber[:var3] = Fiber[:var1] + Fiber[:var2]
        end

        it 'prints the fiber storage' do
          expect { ImLost.vars(Fiber.current) }.to write <<~OUTPUT
            * #{__FILE__}:#{__LINE__ - 1}
              > fiber storage
                var1: 22
                var2: 20
                var3: 42
          OUTPUT
        end

        it 'returns given fiber' do
          ImLost.output = StringIO.new # prevent output

          expect(ImLost.vars(Fiber.current)).to be Fiber.current
        end
      end

      context 'when a different Fiber is given' do
        let(:fiber) { Fiber.new { 42 } }

        after { fiber.kill if defined?(fiber.kill) } # Ruby > v3.3.0

        it 'it prints an error message' do
          expect { ImLost.vars(fiber) }.to write <<~OUTPUT
            * #{__FILE__}:#{__LINE__ - 1}
              !!! given Fiber is not the current Fiber
                  #{fiber.inspect}
          OUTPUT
        end
      end
    else
      pending 'for Fiber is not supported on this platform'
    end
  end

  context '.timer' do
    let(:output) { ImLost.output.string }
    let(:reset_output!) { ImLost.output = StringIO.new }

    before { ImLost.output = StringIO.new }
    after { ImLost.timer.delete(ImLost.timer.ids) }

    it 'supports attributes #count, #empty?, #ids' do
      expect(ImLost.timer).to have_attributes(count: 0, empty?: true, ids: [])

      ids = 5.times.map { ImLost.timer.create }

      expect(ImLost.timer).to have_attributes(
        count: ids.size,
        empty?: false,
        ids: ids
      )
    end

    it 'prints information when an anonymous timer is created' do
      id = ImLost.timer.create

      expect(output).to eq "T #{id}: created\n  #{__FILE__}:#{__LINE__ - 2}\n"
    end

    it 'prints information when a named timer is created' do
      ImLost.timer.create(:tt1)

      expect(output).to eq "T tt1: created\n  #{__FILE__}:#{__LINE__ - 2}\n"
    end

    it 'prints runtime information for an anonymous timer' do
      id = ImLost.timer.create
      reset_output!
      ImLost.timer[id]
      location = Regexp.escape("#{__FILE__}:#{__LINE__ - 1}")

      expect(output).to match(/\AT #{id}: #{RE_FLOAT} sec.\n  #{location}\n\z/)
    end

    it 'prints runtime information for a named timer' do
      ImLost.timer.create(:tt2)
      reset_output!
      ImLost.timer[:tt2]
      location = Regexp.escape("#{__FILE__}:#{__LINE__ - 1}")

      expect(output).to match(/\AT tt2: #{RE_FLOAT} sec.\n  #{location}\n\z/)
    end

    context '.timer#all' do
      it 'prints the runtime of all timers' do
        ImLost.timer.create(:first)
        second = ImLost.timer.create
        reset_output!

        ImLost.timer.all
        location = Regexp.escape("#{__FILE__}:#{__LINE__ - 1}")

        expect(output).to match(
          /\AT #{second}: #{RE_FLOAT} sec.\n  #{location}\n(?#
          )T first: #{RE_FLOAT} sec.\n  #{location}\n\z/
        )
      end
    end
  end
end
