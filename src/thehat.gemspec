# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thehat/version'

Gem::Specification.new do |spec|
  spec.name          = "thehat"
  spec.version       = Thehat::VERSION
  spec.authors       = ["Dave Parker"]
  spec.email         = ["daveparker01@gmail.com"]
  spec.summary       = %q{TheHat task coordination toolkit}
  spec.homepage      = "http://github.com/svdasein/thehat"
  spec.license       = "GPL-2"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ['thehat-irc','thehat-xmpp','thehat-tty','planner-to-flow']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency "xmpp4r"
  spec.add_runtime_dependency "cinch"
  spec.add_runtime_dependency "icalendar"
  spec.add_runtime_dependency "xml-simple"
end

