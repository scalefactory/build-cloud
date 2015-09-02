# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "build-cloud"
  spec.version       = "0.0.13"
  spec.authors       = ["The Scale Factory"]
  spec.email         = ["info@scalefactory.com"]
  spec.summary       = %q{Tools for building resources in AWS}
  spec.homepage      = "https://github.com/scalefactory/build-cloud"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"

  spec.add_dependency "fog", ">=1.22.0"
  spec.add_dependency "pry", ">=0.9.12.6"
end
