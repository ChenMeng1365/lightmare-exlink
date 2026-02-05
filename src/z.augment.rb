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
# dir = "#{base}/yin-ct-snc-1018"
# dir = "#{base}/yin-huawei-ne40-v8r12"
dir = "#{base}/yin-huawei-ne40-v8r22"
# dir = "#{base}/yin-huawei-ne5000-v8r11"
# dir = "#{base}/yin-zte-m6000-v50010"
# dir = "#{base}/yin-zte-t8000-v40010"

search = ''
report, models = [], []
start = Time.new

module_table = Dir["#{dir}/*.yin"].inject([]) do|module_table, path|
  if path.include?(search)
    model = XmlParser.load(path)
    models << model
    module_table << {"#{model.name}:#{model.attributes['name']}" => path}
  else
    module_table
  end
end


module YTree
  def self.walk_custom models
    report = []
    models.each do|model|
      model.elements.each do|node|

        report += YTree.walk(node, [])do|subnode|
          [subnode, subnode.name, subnode.attributes['value']]
        end
        
      end
    end
    return report
  end
end

report = YTree.walk_custom(models)

report.select{|s|s[1]=='extension'}.each do|r|
  pp ycheck!(r[0], 'extension')
end


  # list = YTree.walk(node, []){|subnode|
  #   full_path = YTree.path(subnode) do|n|
  #     n_name = ((n.name=='augment'&&n.attributes['target-node']) ? "{#{n.attributes['target-node']}}" : n.attributes['name'])
  #     n_name = "<#{n.name}>#{n_name}"
  #     n_name = n.name.include?('list') ? n_name+'/*' : n_name
  #     n_name
  #   end
  # end


# File.write 'y.doc.txt', report.join("\n\n")
# File.write 'y.checkout.log', YTree.debug.join("\n").gsub("\n\n\n","")

finish = Time.new
puts start, finish