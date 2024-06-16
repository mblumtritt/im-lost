# frozen_string_literal: true

require 'stringio'

RSpec::Matchers.define :write do |expected|
  match do |actual|
    next false unless actual.is_a? Proc
    oa = ImLost.output
    ImLost.output = StringIO.new
    actual.call
    expect(@actual = ImLost.output.string).to eq expected
  ensure
    ImLost.output = oa if oa
  end

  failure_message { <<~MESSAGE }
    expected: #{expected.inspect}
    got:      #{@actual.inspect}

    diff:     #{differ.diff_as_string(@actual, expected)}
  MESSAGE

  def differ
    prep = ->(o) { RSpec::Matchers::Composable.surface_descriptions_in(o) }
    RSpec::Support::Differ.new(
      object_preparer: prep,
      color: RSpec::Matchers.configuration.color?
    )
  end

  supports_block_expectations
end
