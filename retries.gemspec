require_relative 'lib/retries.rb'

Gem::Specification.new do |gem|
  gem.authors       = ['Caleb Spare']
  gem.email         = ['caleb@ooyala.com']
  gem.summary       = 'Gem for retrying blocks'
  gem.description   =
    'Retries is a gem for retrying blocks with randomized exponential backoff.'
  gem.homepage      = 'https://github.com/ooyala/retries'

  gem.files         = ['lib/retries.rb']
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'retries'
  gem.require_paths = ['lib']
  gem.version       = Retries::VERSION
  gem.license       = 'MIT'

  # For running the tests
  gem.add_development_dependency 'minitest', '~> 5.0'
  gem.add_development_dependency 'rake', '~> 10.0'
  gem.add_development_dependency 'rr', '~> 1.1'

  # For generating the documentation
  gem.add_development_dependency 'redcarpet', '~> 3.4'
  gem.add_development_dependency 'yard', '~> 0.9'

  # For linting
  gem.add_development_dependency 'rubocop', '~> 0.52'
end
