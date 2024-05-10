# frozen_string_literal: true

require 'stringio'
require_relative '../lib/im-lost'

$stdout.sync = $stderr.sync = $VERBOSE = true
RSpec.configure(&:disable_monkey_patching!)
