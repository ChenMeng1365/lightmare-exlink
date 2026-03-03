#!/usr/local/bin/ruby
#coding:utf-8
$LOAD_PATH<<'.'
require 'lib/cc-cache'

head = '/home/leoma/workspace/doc'
adir = ARGV[0]
bdir = ARGV[1]

bdir = 'tmp'
adir = 'yin-ct-snc-0406'

File.write "compare-diffs.txt", File.diffs(adir, bdir, head)



