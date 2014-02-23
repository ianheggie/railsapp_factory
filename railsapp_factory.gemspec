# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'railsapp_factory/version'

Gem::Specification.new do |spec|
  spec.name          = "railsapp_factory"
  spec.version       = RailsappFactory::VERSION
  spec.authors       = ["Ian Heggie"]
  spec.email         = ["ian@heggie.biz"]
  spec.description   = %q{Rails application factory to make testing gems against multiple versions easier}
  spec.summary       = %q{The prupose of this gem is to make integration testing of gems and libraries against multiple versions of rails easy and avoid having to keep copies of the framework in the gem being tested}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "bundler", "~> 1.3"
  spec.add_dependency "activesupport", ">= 2.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", '~> 2.12'
end
