#coding:utf-8
$LOAD_PATH<<'..'

if $product
  require 'lightmare-exlink'
else
  require 'lib/xml-cache'
  # require 'lightmare-exlink/rose/ic-xml'
  require 'lightmare-exlink/xiaolong/xtree'
  require 'lightmare-exlink/xiaolong/ytree'
  require 'lightmare-exlink/xiaolong/ycheck'
  require 'lightmare-exlink/xiaolong/ycheck-ext'
  require 'lightmare-exlink/xiaolong/ytopo'
end

require "roda"

$base = '/home/leoma/workspace/doc'

class App < Roda
  route do |r|
    r.post 'num' do
      rand(100000000).to_s
    end

    r.post 'doc' do
      report,models = [], []
      subs = r.params['submod'].to_s.split(',')
      module_table = Dir["#{$base}/yin-#{r.params['spec']}/*.yin"].inject([]) do|module_table, path|
        if subs.inject(false){|flag,subz|flag || path.include?(subz)}
          model = XmlParser.load(path)
          models << model
          module_table << {"#{model.name}:#{model.attributes['name']}" => path}
        else
          module_table
        end
      end

      node_table, ref_table = YTree.walk_fulldoc(models,
        # 筛选选项
        term:       (r.params['term'] || :all).to_sym,    # 筛选节点范围(默认全选)
        leaf:       ('true' == r.params['leaf'].to_s) || !r.params['leaf'], # 仅输出leaf节点(默认leaf)
        typepath:   (false || r.params['typepath']),      # 筛选节点路径时带<类型名称>(默认不带)
        nspath:     (false || r.params['nspath']),        # 筛选节点路径时带"命名空间:"(默认不带)
        vocab:      r.params['vocab'].to_s.split(","),    # 增加额外的节点类型进行筛选(默认类型:typedef type enum leaf leaf-list container grouping augment refine list choice)
        seltype:    r.params['seltype'].to_s.split(","),  # 特定节点类型被筛选保留
        seltag:     r.params['seltag'].to_s.split(","),   # 特定节点摘要被筛选保留
        linkref:    (false || r.params['linkref']),       # 查询关联引用的节点
        match:      (r.params['match'] || :all).to_sym,   # 筛选节点路径需满足所有条件(默认满足所有,需和tags选项同时使用)
        tags:       r.params['tags'].to_s.split(','),     # 筛选节点路径集合(默认为空不参与筛选)
        # 打印选项
        doc:        (false || r.params['doc']),      # 展示节点文档
        child:      (false || r.params['child']),    # 展示子节点列表
        abstract:   (false || r.params['abstract']), # 展示节点摘要
        prefix:     (nil   || r.params['prefix']),   # 选择是否用指定前缀替换路径前缀(非nil且非空字符串)
        type:       (false || r.params['type']),     # 选择是否显示路径中节点的类型
        namespace:  (false || r.params['namespace']) # 选择是否显示路径中节点的命名空间
      )

      report += ['<<loading-modules>>', module_table.map{|m|m.to_s}.join("\n"), '<<namespace-mapping>>', ref_table.to_yaml]
      report += ['<<finding-results>>'] + node_table.map{|n|n[1..-1].join("\n")}
      report.join("\n\n")
    end
  end
end

run App
