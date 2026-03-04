#!/usr/bin/env ruby
#coding:utf-8
require 'lightmare-exlink'

start = Time.new

base = 'yenv/_ic_'

dir = "#{base}/ydk-models-ct-snc-0402"
search = ['ct-bgp','ct-types']
# search = ['ct-qos','ct-types']

# dir = "#{base}/ydk-models-cx600-v8r21-0.1.2"
# search = ['huawei-bgp', 'huawei-network-instance']
# search = ['huawei-qos', 'huawei-network-instance']

# dir = "#{base}/ydk-models-zte-0.1.1"
# search = ['zxr10-bgp']
# search = ['zxr10-qos']

query = YAML.load(DATA.read)
models = YTree.load(dir,search)
result = YTree.seek_path(models, query)

# File.write "report.txt",$report.map{|r|r.to_s}.join("\n")
File.write "result.txt",result.map{|show|show.join("\n")}.sort.join("\n")

puts Time.new-start

__END__
--- # query
target-node:
  nil
  # type: leaf
  # name: peer
relay-node:
  []
  # - type: container
  # - name: instance
path:
  []
  # - ''
option:
  []
  # - type
  # - doc