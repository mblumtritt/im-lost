# frozen_string_literal: true

require 'stringio'
require_relative '../lib/im-lost'

$stdout.sync = $stderr.sync = $VERBOSE = true
RSpec.configure(&:disable_monkey_patching!)

RE_FLOAT = '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?'
