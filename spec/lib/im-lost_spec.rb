# frozen_string_literal: true

class TestSample
  def initialize
    @state = :created
  end

  def add(arg0, arg1)
    @result = arg0 + arg1
  end

  def add_kw(arg0:, arg1:)
    @result = arg0 + arg1
  end

  def add_block(arg0, &block) = add(arg0, block&.call || 42)
  def map(*args) = args.map(&:to_s)
  def insp(**kw_args) = kw_args.inspect
  def fwd(...) = add(...)
  def foo = :foo
  def bar = :bar
end

RSpec.describe ImLost do
  let(:sample) { TestSample.new }
  let(:output) { ImLost.output.string }

  before { ImLost.output = StringIO.new }
  after { ImLost.untrace_all! }

  it 'has defined default attributes' do
    is_expected.to have_attributes(
      caller_locations: true,
      trace_calls: true,
      trace_results: false
    )
  end

  context 'trace method calls' do
    before do
      ImLost.trace_calls = true
      ImLost.caller_locations = false
      ImLost.trace_results = false
      ImLost.trace(sample)
    end

    it 'traces method calls' do
      sample.foo
      sample.bar

      expect(output).to eq "> TestSample#foo()\n> TestSample#bar()\n"
    end

    it 'includes arguments in call signatures' do
      sample.add(21, 21)

      expect(output).to eq "> TestSample#add(21, 21)\n"
    end

    it 'includes keyword arguments in call signatures' do
      sample.add_kw(arg0: 21, arg1: 21)

      expect(output).to eq "> TestSample#add_kw(21, 21)\n"
    end

    it 'includes block arguments in call signatures' do
      block = proc { 42 }
      sample.add_block(21, &block)

      expect(output).to eq <<~OUTPUT
        > TestSample#add_block(21, &#{block.inspect})
        > TestSample#add(21, 42)
      OUTPUT
    end

    it 'includes splat arguments' do
      sample.map(1, 2, 3, 4)

      expect(output).to eq "> TestSample#map(*[1, 2, 3, 4])\n"
    end

    it 'includes empty splat arguments' do
      sample.map

      expect(output).to eq "> TestSample#map(*[])\n"
    end

    it 'includes keyword splat arguments' do
      sample.insp(a: 1, b: 2)

      expect(output).to eq "> TestSample#insp(**{:a=>1, :b=>2})\n"
    end

    it 'includes empty keyword splat arguments' do
      sample.insp

      expect(output).to eq "> TestSample#insp(**{})\n"
    end

    it 'handles argument forwarding' do
      sample.fwd(40, 2)

      if RUBY_VERSION.to_f < 3.1
        expect(output).to eq <<~OUTPUT
          > TestSample#fwd(*, &)
          > TestSample#add(40, 2)
        OUTPUT
      else
        expect(output).to eq <<~OUTPUT
          > TestSample#fwd(*, **, &)
          > TestSample#add(40, 2)
        OUTPUT
      end
    end

    it 'can trace an object in a block only' do
      example = TestSample.new
      example.foo
      ImLost.trace(example) { |obj| obj.add(20, 22) }
      example.foo

      expect(output).to eq "> TestSample#add(20, 22)\n"
    end

    it 'can include caller locations' do
      ImLost.caller_locations = true
      sample.foo

      expect(output).to eq <<~OUTPUT
        > TestSample#foo()
          #{__FILE__}:#{__LINE__ - 4}
      OUTPUT
    end
  end

  context 'trace method call results' do
    before do
      ImLost.trace_calls = false
      ImLost.caller_locations = false
      ImLost.trace_results = true
      ImLost.trace(sample)
    end

    it 'traces method call results' do
      sample.foo
      sample.bar

      expect(output).to eq <<~OUTPUT
        < TestSample#foo()
          = :foo
        < TestSample#bar()
          = :bar
      OUTPUT
    end

    it 'includes arguments in call signatures' do
      sample.add(21, 21)

      expect(output).to eq "< TestSample#add(21, 21)\n  = 42\n"
    end

    it 'includes block arguments in call signatures' do
      block = proc { 42 }
      sample.add_block(21, &block)

      expect(output).to eq <<~OUTPUT
        < TestSample#add(21, 42)
          = 63
        < TestSample#add_block(21, &#{block.inspect})
          = 63
      OUTPUT
    end

    it 'includes splat arguments' do
      sample.map(1, 2, 3, 4)

      expect(output).to eq <<~OUTPUT
        < TestSample#map(*[1, 2, 3, 4])
          = ["1", "2", "3", "4"]
      OUTPUT
    end

    it 'includes empty splat arguments' do
      sample.map
      expect(output).to eq "< TestSample#map(*[])\n  = []\n"
    end

    it 'includes keyword splat arguments' do
      sample.insp(a: 1, b: 2)

      expect(output).to eq <<~OUTPUT
        < TestSample#insp(**{:a=>1, :b=>2})
          = "{:a=>1, :b=>2}"
      OUTPUT
    end

    it 'includes empty keyword splat arguments' do
      sample.insp

      expect(output).to eq "< TestSample#insp(**{})\n  = \"{}\"\n"
    end

    it 'handles argument forwarding' do
      sample.fwd(40, 2)

      if RUBY_VERSION.to_f < 3.1
        expect(output).to eq <<~OUTPUT
          < TestSample#add(40, 2)
            = 42
          < TestSample#fwd(*, &)
            = 42
        OUTPUT
      else
        expect(output).to eq <<~OUTPUT
          < TestSample#add(40, 2)
            = 42
          < TestSample#fwd(*, **, &)
            = 42
        OUTPUT
      end
    end

    it 'can trace an object`s call results in a block only' do
      example = TestSample.new
      example.foo
      ImLost.trace(example) { |obj| obj.add(20, 22) }
      example.foo

      expect(output).to eq "< TestSample#add(20, 22)\n  = 42\n"
    end
  end

  context '.trace_exceptions' do
    it 'traces exceptions and rescue blocks' do
      ImLost.trace_exceptions do
        raise(ArgumentError, 'not the answer - 21')
      rescue ArgumentError
        # nop
      end

      if RUBY_VERSION.to_f < 3.3
        expect(output).to eq <<~OUTPUT
          x ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 8}
        OUTPUT
      else
        expect(output).to eq <<~OUTPUT
          x ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 13}
          ! ArgumentError: not the answer - 21
            #{__FILE__}:#{__LINE__ - 14}
        OUTPUT
      end
    end

    it 'allows to disable location information' do
      ImLost.trace_exceptions(with_locations: false) do
        raise(ArgumentError, 'not the answer - 21')
      rescue ArgumentError
        # nop
      end

      if RUBY_VERSION.to_f < 3.3
        expect(output).to eq "x ArgumentError: not the answer - 21\n"
      else
        expect(output).to eq <<~OUTPUT
          x ArgumentError: not the answer - 21
          ! ArgumentError: not the answer - 21
        OUTPUT
      end
    end

    it 'allows to be stacked' do
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
      begin
        raise(NotImplementedError)
      rescue NotImplementedError
        # nop
      end

      if RUBY_VERSION.to_f < 3.3
        expect(output).to eq <<~OUTPUT
          x ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 17}
          x ArgumentError: not the answer - 21
        OUTPUT
      else
        expect(output).to eq <<~OUTPUT
          x ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 23}
          ! ArgumentError: not the answer - 42
            #{__FILE__}:#{__LINE__ - 24}
          x ArgumentError: not the answer - 21
          ! ArgumentError: not the answer - 21
        OUTPUT
      end
    end
  end

  context 'trace locations' do
    it 'writes call location' do
      ImLost.here

      expect(output).to eq ": #{__FILE__}:#{__LINE__ - 2}\n"
    end

    it 'writes only when given condition is truethy' do
      ImLost.here(1 < 2)
      ImLost.here(1 > 2)

      expect(output).to eq ": #{__FILE__}:#{__LINE__ - 3}\n"
    end

    it 'returns given argument' do
      expect(ImLost.here(:foo)).to be :foo
      expect(output).to eq ": #{__FILE__}:#{__LINE__ - 1}\n"
    end

    it 'writes only when given block result is truethy' do
      ImLost.here { 1 < 2 }
      ImLost.here { 1 > 2 }

      expect(output).to eq ": #{__FILE__}:#{__LINE__ - 3}\n"
    end

    it 'returns block result' do
      expect(ImLost.here { :foo }).to be :foo
      expect(output).to eq ": #{__FILE__}:#{__LINE__ - 1}\n"
    end
  end

  context 'dump vars' do
    it 'prints instance variables' do
      sample.add(22, 20)
      ImLost.vars(sample)

      expect(output).to eq <<~OUTPUT
        = #{__FILE__}:#{__LINE__ - 3}
          instance variables:
          @result: 42
          @state: :created
      OUTPUT
    end

    it 'returns given object' do
      expect(ImLost.vars(sample)).to be sample
    end

    context 'when a Binding is given' do
      it 'prints local variables' do
        test = :test
        sample = test.to_s
        test = sample
        ImLost.vars(binding)

        expect(output).to eq <<~OUTPUT
          = #{__FILE__}:#{__LINE__ - 3}
            local variables:
            sample: "test"
            test: "test"
        OUTPUT
      end

      it 'returns ImLost' do
        expect(ImLost.vars(binding)).to be ImLost
      end
    end
  end

  context 'anonymous timer' do
    before { ImLost.caller_locations = true }

    it 'prints the location of the timer creation' do
      timer = ImLost.timer.create
      ImLost.timer.delete(timer)

      expect(output).to eq "T* #{timer}\n  #{__FILE__}:#{__LINE__ - 3}\n"
    end

    it 'prints the runtime since the timer was created' do
      timer = ImLost.timer.create
      ImLost.output = StringIO.new # reset output
      ImLost.timer.delete(ImLost.timer[timer])

      expect(output).to match(
        /\A#{
          Regexp.escape("T #{timer}\n  #{__FILE__}:#{__LINE__ - 4}")
        }\n  #{RE_FLOAT} sec.\n\z/
      )
    end
  end

  context 'named timer' do
    before { ImLost.caller_locations = true }

    it 'prints the location of the timer creation' do
      ImLost.timer.create(:tt1)

      expect(output).to eq "T* tt1\n  #{__FILE__}:#{__LINE__ - 2}\n"

      ImLost.timer.delete(:tt1)
    end

    it 'prints the runtime since the timer was created' do
      ImLost.timer.create(:tt2)
      ImLost.output = StringIO.new # reset output
      ImLost.timer.delete(ImLost.timer[:tt2])

      expect(output).to match(
        /\A#{
          Regexp.escape("T tt2\n  #{__FILE__}:#{__LINE__ - 4}")
        }\n  #{RE_FLOAT} sec.\n\z/
      )
    end
  end
end
