#!/usr/local/bin/ruby
#coding:utf-8
$:<<'.'

if $product
  require 'lightmare-exlink'
else
  require 'lib/xml-cache'
  require 'lightmare-exlink/xiaolong/ytree'
  require 'lightmare-exlink/xiaolong/ycheck'
  require 'lightmare-exlink/xiaolong/ycheck-ext'
  require 'lightmare-exlink/xiaolong/ytopo'
end

base = '/home/leoma/workspace/doc'
dir = "#{base}/yin-ct-snc-1018"
# dir = "#{base}/yin-huawei-ne40-v8r12"
# dir = "#{base}/yin-huawei-ne40-v8r22"
# dir = "#{base}/yin-huawei-ne5000-v8r11"
# dir = "#{base}/yin-zte-m6000-v50010"
# dir = "#{base}/yin-zte-t8000-v40010"

search = ['ct-bgp@2022-05-07']
# search = ['bgp', 'network-instance']
models, report = [], []
start = Time.new

module_table = Dir["#{dir}/*.yin"].inject([]) do|module_table, path|
  if search.inject(false){|flag,subz|flag || path.include?(subz)}
    model = XmlParser.load(path)
    models << model
    module_table << {"#{model.name}:#{model.attributes['name']}" => path}
  else
    module_table
  end
end


process_table, reference_table = YTree.walk_linkdoc(models,{
  tags: ''.split(','),
  leaf: false,
  linkref: true,

  # doc: true,
  # abstract: true,
  type: true
})
File.write "ytree-linkdoc.txt", process_table.map{|pt|pt[1..3].join("\n")}.sort.uniq.join("\n")


finish = Time.new
puts finish-start