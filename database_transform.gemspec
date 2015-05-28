# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'database_transform/version'

Gem::Specification.new do |spec|
  spec.name          = 'database_transform'
  spec.version       = DatabaseTransform::VERSION
  spec.authors       = ['Joel Low']
  spec.email         = ['joel@joelsplace.sg']

  spec.summary       = "Transforms the data of a database from an old schema to a new one."
  spec.description   = "Transforms the data of a database from an old schema to a new one."
  spec.homepage      = 'https://github.com/lowjoel/database_transform'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'activerecord'

  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3'

  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'codeclimate-test-reporter'
end
