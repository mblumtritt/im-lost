# frozen_string_literal: true

require_relative 'lib/im-lost/version'

Gem::Specification.new do |spec|
  spec.name = 'im-lost'
  spec.version = ImLost::VERSION
  spec.summary = 'Your debugging helper.'
  spec.description = <<~DESCRIPTION
    If you have overlooked something again and don't really understand what
    your code is doing. If you have to maintain this application but can't
    really find your way around and certainly can't track down that stupid
    error. If you feel lost in all that code, here's the gem to help you out!

    ImLost helps you by analyzing function calls of objects, informing you
    about exceptions and logging your way through your code. In short, ImLost
    is your debugging helper!
  DESCRIPTION

  spec.author = 'Mike Blumtritt'
  spec.license = 'MIT'
  spec.homepage = 'https://codeberg.org/mblumtritt/im-lost'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/im-lost'

  spec.required_ruby_version = '>= 3.0'

  spec.files = Dir['lib/**/*'] + Dir['examples/**/*']
  spec.extra_rdoc_files = %w[README.md LICENSE]
end
