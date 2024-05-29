# frozen_string_literal: true

$stdout.sync = $stderr.sync = $VERBOSE = true

RSpec.configure(&:disable_monkey_patching!)

require 'stringio'

RE_FLOAT = '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?'

require_relative '../lib/im-lost'
