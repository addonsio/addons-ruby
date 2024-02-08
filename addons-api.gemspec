# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'addons-api/version'

Gem::Specification.new do |spec|
  spec.name          = 'addons-api'
  spec.version       = AddonsApi::VERSION
  spec.authors       = ['motymichaely']
  spec.email         = ['moty@crazyantlabs.com']
  spec.description   = 'Ruby HTTP client for the Addons.io API.'
  spec.summary       = 'Ruby HTTP client for the Addons.io API. Learn more on https://addons.io'
  spec.homepage      = 'https://github.com/addonsio/addons-ruby'
  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', "~> 2.3"
  spec.add_development_dependency 'rake', "~> 13.0"
  spec.add_development_dependency 'yard', "~> 0.9"
  spec.add_development_dependency 'pry', "~> 0.13"
  spec.add_development_dependency 'netrc', "~> 0.11"
  spec.add_development_dependency 'rspec', "~> 3.12"

  spec.add_dependency "oj", "~> 3.14"
  spec.add_dependency "rest-client", "~> 2.1"

end