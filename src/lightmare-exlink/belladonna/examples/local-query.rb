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

base = '/home/ubuntu/workspace/doc'
# dir = "#{base}/yin-ct-snc-1018"
# dir = "#{base}/yin-huawei-ne40-v8r12"
dir = "#{base}/yin-huawei-ne40-v8r22"
# dir = "#{base}/yin-huawei-ne5000-v8r11"
# dir = "#{base}/yin-zte-m6000-v50010"
# dir = "#{base}/yin-zte-t8000-v40010"

search = ['bgp', 'network-instance']
models, report = [], []
start = Time.new

module_table = Dir["#{dir}/*.yin"].inject([]) do|module_table, path|
  if search.inject(false){|flag, spath| flag || path.include?(spath)}
    model = XmlParser.load(path)
    models << model
    module_table << {"#{model.name}:#{model.attributes['name']}" => path}
  else
    module_table
  end
end

node_table, ref_table = YTree.walk_fulldoc(models,
  # 筛选选项
  # term:       :all,   # 选择节点范围(:all|:leaf|:unleaf, 默认:all)
  # leaf:       false,  # 输出节点时仅leaf节点(筛选不影响关联节点, 默认为true只筛选leaf)
  # typepath:   true,   # 筛选节点路径时带<类型名称>(默认false) ※ <choice>/<case>只在带类型的路径筛选中显示
  # nspath:     true,   # 筛选节点路径时带"命名空间:"(默认false)
  # vocab:      [''],   # 增加额外的节点类型进行筛选(逗号隔开, 默认类型:typedef type enum leaf leaf-list container grouping augment refine list choice)
  # linkref:    :yes,   # 查询关联引用的节点
  # match:      :all,   # 筛选节点路径需满足所有条件(默认满足所有, 需和tags选项同时使用)
  # match:      :any,   # 筛选节点路径仅需满足其一条件(需和tags选项同时使用)
  # tags:       [''],   # 筛选节点路径集合(逗号隔开, 默认为空不参与筛选)

  # 打印选项
  # doc:        :yes,   # 展示节点文档
  # abstract:   :yes,   # 展示节点摘要
  # prefix:     '',     # 选择是否用指定前缀替换路径前缀
  # type:       :yes,   # 选择是否显示路径中节点的类型
  # namespace:  :yes    # 选择是否显示路径中节点的命名空间
)

report += ['<<loading-modules>>', module_table.map{|m|m.to_s}.join("\n"), '<<namespace-mapping>>', ref_table.to_yaml]
report += ['<<finding-results>>'] + node_table.map{|n|n[1..-1].join("\n")}

File.write 'doc.txt', report.join("\n\n")
File.write 'checkout.log', YTree.debug.join("\n").gsub("\n\n\n","")
finish = Time.new
puts start, finish