#!/usr/local/bin/ruby
#coding:utf-8
$LOAD_PATH<<'.'

if $product
  require 'lightmare-exlink'
else
  require 'lib/xml-cache'
  require 'lightmare-exlink/xiaolong/ytree'
  require 'lightmare-exlink/xiaolong/ycheck'
  require 'lightmare-exlink/xiaolong/ycheck-ext'
  require 'lightmare-exlink/xiaolong/ytopo'
end

$base = '/home/leoma/workspace/doc'
report    = []

# spec      = 'huawei-ne5000-v8r11'
# spec      = 'huawei-ne40-v8r12'
spec      = 'huawei-ne40-v8r22'
# spec      = 'zte-m6000-v50010'
# spec      = 'zte-t8000-v40010'
submod    = 'bgp'

type      = false
prefix    = false
doc       = false
match     = 'advertise-route-to-evpn'
tags      = []
unterm    = false
namespace = false

Dir["#{$base}/yin-#{spec}/*.yin"].each do|path|
  next unless path.include?(submod)
  model = XmlParser.load(path)
  report << JSON.pretty_generate(model.attributes.merge("filepath" => path, "common-prefix" => prefix))

  model.elements.each do|node|
    if ytree?(node)
      list = YTree.walk_pathdoc(node, type: type, match: match, prefix: prefix, tags: tags, doc: doc, unterm: unterm, namespace: namespace)
      list = doc ? list.map{|n|[n[1..-1]].join("\n")} : list.map{|n|n[1]}
      report << Array.new(128,"-").join+"\n"+list.join("\n\n")
    else
      # other functions
    end
  end
  report << "\n"+Array.new(128,"-").join()+"\n"
end

File.write "y.doc-old.txt", report.join("\n")