# -*- encoding: utf-8 -*-
require File.expand_path('../lib/retries/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Caleb Spare"]
  gem.email         = ["caleb@ooyala.com"]
  gem.description   = %q{Retries is a gem for retrying blocks with randomized exponential backoff.}
  gem.summary       = %q{Retries is a gem for retrying blocks with randomized exponential backoff.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "retries"
  gem.require_paths = ["lib"]
  gem.version       = Retries::VERSION

  # For running the tests
  gem.add_development_dependency "rake"
  gem.add_development_dependency "scope"

  # For generating the documentation
  gem.add_development_dependency "yard"
  gem.add_development_dependency "redcarpet"
end
