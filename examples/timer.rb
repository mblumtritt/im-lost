# frozen_string_literal: true

puts <<~INFO

  This is an example how to use named and anonymous timers.

INFO

require_relative '../lib/im-lost'

puts 'Create a named timer:'
ImLost.timer.create(:first)

puts 'Create an anonymous timer:'
second = ImLost.timer.create

sleep(0.5) # or whatever

puts 'print runtime for named timer:'
ImLost.timer[:first]

puts 'print runtime for anonymous named timer:'
ImLost.timer[second]

puts 'delete a named timer'
ImLost.timer.delete(:first)

puts 'delete an anonymous timer'
ImLost.timer.delete(second)
