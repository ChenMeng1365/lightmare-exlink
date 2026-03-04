require_relative 'mekkalight'

Gem::Specification.new do |spec|
  spec.name          = "mekkalight"
  spec.version       = '0.1.0'
  spec.authors       = ["Matt"]
  spec.email         = ["matthrewchains@gmail.com"]

  spec.summary       = %q{mekkalight}
  spec.description   = %q{mekkalight}

  spec.files         = [
    'mekkalight',
    'linkdown',
  ].map{|file|"#{file}.rb"}

  spec.bindir        = "bin"
  spec.executables   = ["ml"]

  spec.require_paths = ["."]
end