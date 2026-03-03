#!/usr/local/bin/ruby
#coding:utf-8
#FILE: lm-runner.rb
$:<<'.'
require 'lightmare-exlink' # or require 'lightmare-exlink/easyline'
name, root, debug = ARGV[0..2]

# $: ./lm-runner.rb [dir:]*SCRIPT_PATH MODULE_NAME [DEBUG_FLAG]*
if name[0..3]=='dir:'
  dir = name[4..-1].split("/")
  dir << "*.lm"
  Dir["#{dir.join('/')}"].each do|path|
    EasyLine.translate(name: (path[-3..-1]=='.lm' ? path[0..-4] : path), root: root, debug: debug)
  end
else
  EasyLine.translate(name: (name[-3..-1]=='.lm' ? name[0..-4] : name), root: root, debug: debug)
end
