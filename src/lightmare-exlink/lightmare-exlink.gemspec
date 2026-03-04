require_relative 'lightmare-exlink'

Gem::Specification.new do |spec|
  spec.name          = "lightmare-exlink"
  spec.version       = '1.7.0'
  spec.authors       = ["Matt"]
  spec.email         = ["matthrewchains@gmail.com"]

  spec.summary       = %q{The exlink model and tools of YANG}
  spec.description   = %q{Lightmare is a document tool for YANG models which represent as XML Tree, it provides lex, parsing and asymanufactoring functions.}

  spec.files         = [
    'lightmare-exlink',
    'rose/lex',
    'rose/ic-xml',
    'xiaolong/xtree',
    'xiaolong/easyline',
    'xiaolong/ytree',
    'xiaolong/ycheck',
    'xiaolong/ycheck-ext',
    'xiaolong/ytopo',
    'xiaolong/ybehave'
  ].map{|file|"#{file}.rb"}

  spec.bindir        = "schnee"
  spec.executables   = ["lm", "lms", "lmx", "ym", "ys"]

  spec.require_paths = ["."]
end