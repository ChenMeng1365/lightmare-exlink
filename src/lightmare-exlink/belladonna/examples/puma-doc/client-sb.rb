#!/usr/local/bin/ruby
#coding:utf-8
require "lucid_http"
base = "/home/ubuntu/workspace/dev/atom-cap/tests/data"

form = {
  # 'spec'=> 'huawei-ne5000-v8r11',
  # 'spec'=> 'huawei-ne40-v8r12',
  'spec'=> 'huawei-ne40-v8r22',
  # 'spec'=> 'zte-m6000-v50010',
  # 'spec'=> 'zte-t8000-v40010',

  'submod'=> 'bgp',

  # 筛选选项
  # term:       :all,   # 选择节点范围(:all|:leaf|:unleaf, 默认:all)
  # typepath:   true,   # 筛选节点路径时带<类型名称>(默认false) ※ <choice>/<case>只在带类型的路径筛选中显示
  # nspath:     true,   # 筛选节点路径时带"命名空间:"(默认false)
  # vocab:      '',     # 增加额外的节点类型进行筛选(逗号隔开, 默认类型:typedef type enum leaf leaf-list container grouping augment refine list choice)
  # seltype:    '',     # 筛选特定节点类型被筛选保留(逗号隔开)
  # seltag:     '',     # 筛选特定节点摘要被筛选保留(逗号隔开, 摘要格式)
  # match:      :all,   # 筛选节点路径需满足所有条件(默认满足所有, 需和tags选项同时使用)
  # match:      :any,   # 筛选节点路径仅需满足其一条件(需和tags选项同时使用)
  # tags:       '',     # 筛选节点路径集合(逗号隔开, 默认为空不参与筛选)
  # linkref:    :yes,   # 查询关联引用的节点
  # leaf:       false,  # 输出节点时仅leaf节点(筛选不影响关联节点, 默认为true只筛选leaf)

  # 打印选项
  # abstract:   :yes,   # 展示节点摘要
  # doc:        :yes,   # 展示节点文档
  # child:      :yes,   # 展示下级节点
  # prefix:     '',     # 选择是否用指定前缀替换路径前缀
  # type:       :yes,   # 选择是否显示路径中节点的类型
  # namespace:  :yes    # 选择是否显示路径中节点的命名空间
}

header,report = POST('/doc', form: form).split('<<finding-results>>')
File.open("#{base}/checkout-s-nodes.txt",'w'){|file|file.write report.to_s+"\n\n#{Array.new(64,'-').join}"}
File.open("#{base}/checkout-s-heads.txt", 'w'){|file|file.write header}
