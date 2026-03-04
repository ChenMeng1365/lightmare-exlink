mkdir lib/
cp -rf /home/ubuntu/workspace/dev/research/src/lightmare-exlink lib/
cp -rf /home/ubuntu/workspace/dev/research/src/lib/xml-cache.rb lib/
cp -rf /home/ubuntu/workspace/dev/research/src/lib/cc-cache.rb lib/

cat <<EOF >> Gemfile
source "https://ruby-china.com"

gemspec

gem "rake",     "~> 12.0"
EOF

cat <<EOF >> Rakefile
require "bundler/gem_tasks"
task :default => :spec
EOF

cat <<EOF >> lightmare-exlink.gemspec
require_relative 'lib/lightmare-exlink'

Gem::Specification.new do |spec|
  spec.name          = "lightmare-exlink"
  spec.version       = '1.0.0'
  spec.authors       = ["Matt"]
  spec.email         = ["matthrewchains@gmail.com"]

  spec.summary       = %q{lightmare-exlink}
  spec.description   = %q{lightmare-exlink}

  spec.files         = [
    'lightmare-exlink', 
    'xml-cache', 
    'cc-cache',
    'lightmare-exlink/rose/lex',
    'lightmare-exlink/xiaolong/stree',
    'lightmare-exlink/xiaolong/ntree',
    'lightmare-exlink/xiaolong/xtree',
    'lightmare-exlink/xiaolong/easyline',
    'lightmare-exlink/xiaolong/ytree',
    'lightmare-exlink/xiaolong/ycheck',
    'lightmare-exlink/xiaolong/ycheck-ext',
    'lightmare-exlink/xiaolong/ytopo'
  ].map{|file|"lib/#{file}.rb"}

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.require_paths = ["lib"]
end
EOF

cat <<EOF >> lib/lightmare-exlink.rb
#coding:utf-8
$:<<"lib"

require 'cc-cache'
require 'xml-cache'
require 'lightmare-exlink/xiaolong/stree'
require 'lightmare-exlink/xiaolong/ntree'
require 'lightmare-exlink/xiaolong/xtree'
require 'lightmare-exlink/xiaolong/easyline'
require 'lightmare-exlink/xiaolong/ytree'
require 'lightmare-exlink/xiaolong/ycheck'
require 'lightmare-exlink/xiaolong/ycheck-ext'
require 'lightmare-exlink/xiaolong/ytopo'
require 'lightmare-exlink/rose/lex'

class LightmareExlink
  VERSION = '1.0.0'
  # this version is the same as XiaoLong
end
EOF
