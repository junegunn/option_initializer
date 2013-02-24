# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'option_initializer/version'

Gem::Specification.new do |gem|
  gem.name          = "option_initializer"
  gem.version       = OptionInitializer::VERSION
  gem.authors       = ["Junegunn Choi"]
  gem.email         = ["junegunn.c@gmail.com"]
  gem.description   = %q{Object construction with method chaining}
  gem.summary       = %q{Object construction with method chaining}
  gem.homepage      = "https://github.com/junegunn/option_initializer"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
