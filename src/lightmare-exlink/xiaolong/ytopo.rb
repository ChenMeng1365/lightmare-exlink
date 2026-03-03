#coding:utf-8

module YTree
  module_function

  #####################################################
  # walk扩展                                          #
  #####################################################
  def walk_path node, args={}
    option = {type: true, tags: []}.merge(args)
    list = YTree.walk(node){|node| make_simplepath(node) }
    list.select{|n|
      n.split("/")[-1].include?('leaf:') &&     # 仅保留叶子节点
      option[:tags].inject(true){|f,t|f&&n.include?(t)}  # 根据标签筛选路径
    }.map{|n|
      headn = option[:type] ? n.split('/').map{|j|j.split(':')[-1]}.join('/') : n # 去掉节点类型
      headn = option[:prefix] ? headn.sub(option[:prefix].to_s,'') : headn # 去掉共有前缀
    }
  end

  def walk_doc node, name=nil, type=nil
    list = YTree.walk(node){|node|
      (true && (!name || (name && node.attributes['name']==name)) && (!type || (type && node.name==type)) ) ? node : nil
    }
    list = list.compact.uniq.map{|n|JSON.pretty_generate self.documentize(n)}
  end

  def walk_pathdoc node, args={}
    option = {
      type: false, prefix: false, doc: false, match: nil, tags: [], unterm: false, namespace: false
    }.merge(args)
    list = YTree.walk(node){|node| [node, make_simplepath(node)] }
    
    list = list.select{|n| # 原始值筛选
      option[:unterm] ? true : n[1].split("/")[-1].include?('leaf:') # 是否仅保留叶子节点
    }.map{|n|
      h = option[:type] ? n : [n[0], n[1].split('/').map{|j|j.split(':')[-1]}.join('/')] # 去掉节点类型
      h = option[:prefix] && !option[:prefix].to_s.empty? ? [h[0],h[1].sub(option[:prefix].to_s,'')] : h # 去掉共有前缀
      h = option[:doc] ? h+[JSON.pretty_generate(self.documentize(h[0], namespace: option[:namespace]))] : h
    }.select{|n| # 加工值筛选
      # (option[:tags].inject(true){|f,t|f&&n[1].include?(t)}) && # 根据标签筛选路径 [TODO]: 更复杂的匹配方式 
      (option[:match] ? n[1].include?(option[:match]) : true)
    } # [node, path, doc*]
  end

  def walk_infolist node, model
    return YTree.walk(node, []){|subnode|
      full_path = make_fullpath(subnode)

      keys, mandatory, readonly = [], false, false
      ref_table = subnode.elements.inject([]) do|ref_table, sub2s|
        k = ycheck!(sub2s, 'key'); keys += k['key'] if k['key']
        r = ycheck!(sub2s, 'config'); readonly = !r['config'] if r && r.has_key?('config')
        m = ycheck!(sub2s, 'mandatory'); mandatory = true if m['mandatory']

        has_use = ycheck!(sub2s, 'uses')
        ref_node_ns_name = has_use ? has_use['uses'] : nil
        ref_table << ref_node_ns_name
      end.compact

      tags = [(keys.empty? ? nil : "[K]:{#{keys.join(' ')}}"), (mandatory ? "[M]" : nil), (readonly ? "[R]" : nil)].compact

      [
        subnode,                    # [0]native object
        model.attributes['name'],   # [1]node namespace
        subnode.name,               # [2]node type
        subnode.attributes['name'], # [3]node name
        full_path,                  # [4]node full path
        ref_table,                  # [5]reference nodes name
        tags                        # [6]tags: Key Mandatory Readonly(Config False)
      ]
    }.compact
  end

  def walk_fulldoc models, args={}
    option = make_option(args)
    namespace_map = []   # [[module_name, ref_module_shortname, ref_module_fullname(split(':')[-1]))]]
    all_node_table = []  # [[native-obj, namespace, node-type, node-name, node-fullpath, ref-node-names]]

    models.each do|model|
      namespace_map += make_namespace_map(model) # 记录模块名称和缩写的映射

      # 遍历每个节点求摘要
      model.elements.each do|node|
        all_node_table += YTree.walk_infolist(node, model)
      end
    end

    # 根据vocab, term, typepath, nspath, match和tags筛选节点
    pre_select_table = process_preselect(all_node_table, option)
    select_table = process_select(pre_select_table, option)
    select_table = option[:leaf] ? select_table.select{|s|s[2].include?('leaf')} : select_table

    # 根据依赖关系将目标节点的父节点的引用纳入筛选范围
    ref_node_table, target_table = [], select_table
    for i in 0..3 # 将引用关系关联到的节点进行最多3次再关联, ※ 也可以改成考察到关联超集不再增加为止, 性能权衡
      one_time_table = self.reflies target_table, all_node_table
      ref_node_table += one_time_table
      target_table = one_time_table
    end if option[:linkref]
    
    # 根据seltype, seltype筛选最后需要保留的节点(不删linkref节点)
    post_select_table = (process_postselect(select_table, option) + ref_node_table).uniq

    # 对筛选节点进行处理展示
    process_table = process_finaltable(post_select_table, all_node_table, option)

    # namespace-table: [{ref-shortname, ref-fullname, def-module-names}]
    reference_temp = {}
    namespace_map.each{|item| (reference_temp[ item[1..-1] ] ||= [] ) << item[0] }
    reference_table = reference_temp.map{|items|{'ns'=>items[0][0], 'full-ns'=>items[0][1], 'refs'=>items[1].join(',')}}

    return [process_table, reference_table]
  end

  def walk_linkdoc models, args={}
    option = make_option(args)
    namespace_map = []   # [[module_name, ref_module_shortname, ref_module_fullname(split(':')[-1]))]]
    refer_map = {}       # {module_name => {import => short, short => import}}
    include_map = {}     # {module_name => [submodule_name]}
    all_node_table = []  # [[native-obj, namespace, node-type, node-name, node-fullpath, ref-node-names]]

    models.each do|model|
      namespace_map += make_namespace_map(model) # 记录模块名称和缩写的映射

      # 遍历每个节点求摘要
      model.elements.each do|node|
        make_reference_map(refer_map, model, node) # 构造引用表
        make_include_map(include_map, model, node) # 构造包含表
        all_node_table += YTree.walk_infolist(node,model)
      end
    end

    # 根据依赖关系将目标节点的父节点的引用纳入筛选范围
    for i in 0..3 # 将引用关系关联到的节点进行最多3次再关联, ※ 也可以改成考察到关联超集不再增加为止, 性能权衡
      ref_node_table, target_table = [], all_node_table
      target_table.each do|item|
        ref_table = item[5]
        mod_name  = item[1]
        snodes    = []

        ref_table.each do|ref_node|
          # 寻找节点的uses节点(grouping), 按<module>/<grouping>匹配, module为自身所在模块空间
          ref1,ref2 = ref_node.split(':')
          if ref2
            ref_domain=ref1
            ref_name=ref2
            ref_path = "#{refer_map[mod_name][ref_domain]}/#{ref_name}"
          else
            ref_domain=mod_name
            ref_name=ref1
            ref_path = "#{ref_domain}/#{ref_name}"
          end

          # 已添加则不重复添加
          next if item[0].elements.find{|e|e.name=='grouping' && e.attributes['name']==ref_name}
          # 未添加则寻找并添加
          snodes = target_table.select{|i|i[2]=='grouping' && i[4].split('/').map{|s|s.split('>')[-1]}.join('/')==ref_path}
          
          # 如果uses找不到, 则改为从自身模块include的子模块空间中寻找
          include_map[mod_name].each do|submod_name|
            ref_path = "#{submod_name}/#{ref_name}"
            snodes = target_table.select{|i|i[2]=='grouping' && i[4].split('/').map{|s|s.split('>')[-1]}.join('/')==ref_path}
            break unless snodes.empty?
          end if snodes.empty?

          # ※ 仍然会有部分空引用和空包含
          # puts "#{item[3]} := #{item[4]}\nuses\n#{snodes.first[3]} := #{snodes.first[4]}" unless snodes.empty?
        end

        # 添加实体引用
        snodes.each do|snode|
          inst = snode[0].clone
          inst.parent = item[0]
          item[0].elements << inst unless item[0].elements.find{|e|e.attributes['name']==inst.attributes['name']}
          new_item = [ inst, mod_name, inst.name, inst.attributes['name'], make_fullpath(inst), snode[5], snode[6] ]
          # ref_node_table << new_item
          ref_node_table += YTree.walk_infolist(inst, models.find{|m|m.attributes['name']==mod_name})
        end
      end
      all_node_table += ref_node_table
      all_node_table.uniq!
    end if option[:linkref]

    # 根据vocab, term, typepath, nspath, match和tags筛选节点
    pre_select_table = process_preselect(all_node_table, option)
    select_table = process_select(pre_select_table, option)
    select_table = option[:leaf] ? select_table.select{|s|s[2].include?('leaf')} : select_table

    # 根据seltype, seltype筛选最后需要保留的节点
    post_select_table = process_postselect(select_table, option)

    # 对筛选节点进行处理展示
    process_table = process_finaltable(post_select_table, all_node_table, option)

    # namespace-table: [{ref-shortname, ref-fullname, def-module-names}]
    reference_temp = {}
    namespace_map.each{|item| (reference_temp[ item[1..-1] ] ||= [] ) << item[0] }
    reference_table = reference_temp.map{|items|{'ns'=>items[0][0], 'full-ns'=>items[0][1], 'refs'=>items[1].join(',')}}

    return [process_table, reference_table]
  end

  #####################################################
  # helpers                                           #
  #####################################################
  def reflies select_table, all_node_table
    # 查询select_table中父节点grouping被依赖的节点
    ref_node_table = []
    select_table.each do|item|
      hops = (item[4][0]=='/' ? item[4] : "/"+item[4]).split('/<')
      hops.delete ""
      grouping = hops.map{|h|h.split('>')}[1] # [0]<mod/submod>.../[1]<some-container>.../...
      
      # 1次关联查询
      all_node_table.each do|anynode|
        next if anynode[5].empty?
        flag = anynode[5].inject(false){|flag, use|flag || use.include?(grouping[1])}
        ref_node_table << anynode if flag
      end if grouping[0]=='grouping'
    end
    ref_node_table.uniq!
    return ref_node_table
  end

  # [NoRecommendation]
  def make_simplepath node
    YTree.path(node) do|n|
      name = n.attributes['name'] ? "#{n.name}:#{n.attributes['name']}" : n.name
      name = n.name=='augment' ? "#{name}:#{n.attributes['target-node']}" : name
      n.name=='list' ? name+'/*' : name
    end
  end

  def make_option args={}
    option = {
      term:       :all,  # 筛选选项: 在筛选时选择考察节点类型(:leaf仅leaf节点, :unterm非leaf节点, :all所有节点, ...)
      leaf:       true,  # 筛选选项: 在输出时是否仅包含leaf节点(含leaf关联的节点)
      typepath:   false, # 筛选选项: 在筛选路径时是否考察节点类型
      nspath:     false, # 筛选选项: 在筛选路径时是否考察节点命名空间
      match:      :all,  # 筛选选项: 筛选路径时是匹配所有标签还是匹配任一标签{:all|:any}
      tags:       [],    # 筛选选项: 筛选子路径(※路径是指在综合处理了筛选选项后的路径, 包括list类型对应的星号"*")
      vocab:      [],    # 筛选选项: 指定特定节点类型参与检查
      seltype:    [],    # 筛选选项: 指定特定节点类型被筛选保留
      seltag:     [],    # 筛选选项: 指定特定节点摘要被筛选保留
      linkref:    false, # 筛选选项: 查询关联引用节点
      prefix:     nil,   # 打印选项: 输出的节点路径处理掉某个特定的头部(简化为$PREFIX)
      doc:        false, # 打印选项: 输出是否包括节点文档
      child:      false, # 打印选项: 输出下一级节点
      abstract:   false, # 打印选项: 输出是否包括节点摘要(节点命名空间, 节点类型, 节点名称)
      type:       false, # 打印选项: 输出的节点路径是否带节点类型
      namespace:  false  # 打印选项: 输出的节点路径是否带命名空间
    }.merge(args)
    option[:vocab] += YTree.list
    return option
  end

  def make_fullpath node
    YTree.path(node) do|n|
      # 引入路径
      n_name = ((n.name=='augment'&&n.attributes['target-node']) ? "{#{n.attributes['target-node']}}" : n.attributes['name'])
      # 带上类型节点
      n_name = "<#{n.name}>#{n_name}"
      # 列表元素路径化
      n_name = n.name.include?('list') ? n_name+'/*' : n_name
      n_name
    end
  end

  def make_selpath path, type=false, ns=false
    hops = (path[0]=='/' ? path : "/"+path).split('/<') # add a '/' to split '/<' for each node, then delete empty header
    hops.delete ""; hops = hops.map{|h|'<'+h}
    unless type
      # type: false && namespace: true
      # type: false && namespace: false
      hops = hops.map{|h|a=h.split('>');a.size>1 ? a[1].to_s : "#{a[0]}>"} # delete type in path unless node has no name
      hops = hops.map{|h|h.sub('{/','').sub('}','').split('/')}.flatten # flatten augment path
      hops = hops.map{|h|a=h.split(':');a.size>1 ? a[1].to_s : a[0]} unless ns # delete namespace in path for each node
    else
      # type: true && namespace: true
      # type: true && namespace: false
      # type-prefix in path by-default, ns-prefix maybe exist or not, :namespace just make it notable
      unless ns
        hops = hops.map do|h|
          rtype, rest = h.split('>'); type = rtype+'>'
          mid, post = rest.to_s.split('{'); tail = post ? '{'+post : ''
          left,right = mid.to_s.split(':')
          name = right ? right : left
          [type, name, tail].join
        end
      end
    end
    return hops.join("/")
  end

  def make_namespace_map model
    namespace_map = []
    model.attributes.each do|key, val|
      next if key.is_a?(Symbol) or !key.include?('xmlns:')
      namespace_map << [ model.attributes['name'], key.split(':')[-1], val ]
    end
    return namespace_map
  end

  def make_reference_map refer_map, model, node
    if ycheck?('prefix') # 模块自引用缩写
      ref_ns = ycheck(node, 'prefix')
      refer_map[ model.attributes['name'] ] ||= {}
      refer_map[ model.attributes['name'] ].merge!(ref_ns['prefix']=>model.attributes['name'],model.attributes['name']=>ref_ns['prefix']) if ref_ns['prefix']
    end
    if ycheck?('import') # 模块引用缩写
      ref_ns = ycheck(node, 'import')
      refer_map[ model.attributes['name'] ] ||= {}
      refer_map[ model.attributes['name'] ].merge! ref_ns['import'].merge!(ref_ns['refer']) if ref_ns['import']
    end
  end

  def make_include_map include_map, model, node
    if ycheck?('include')
      inc_name = ycheck(node, 'include')
      include_map[ model.attributes['name'] ] ||= []
      include_map[ model.attributes['name'] ] << inc_name['include'] if inc_name['include']
    end
  end

  def process_preselect node_table, option
    # 根据vocab, term, typepath筛选节点
    pre_select_table = node_table.select do|item|
      flag = true
      flag = flag && option[:vocab].include?(item[2]) if option[:vocab] # 符合节点词汇表
      flag = flag && ( item[2].include?('leaf')) if option[:term]==:leaf          # 符合节点类型,leaf|非leaf|任意
      flag = flag && (!item[2].include?('leaf')) if option[:term]==:unterm
      flag
    end
    unless option[:typepath] # ※ 当类型不参与路径运算时, choice节点首先就被剔除了, 且其余节点的路径也没有<choice>/<case>的内容了, 小心<case>仅引用<uses>的情况
      pre_select_table = pre_select_table.select{|i|!['choice','case'].include?(i[2])}.map do|item|
        newpath = item[4].split('/<').select{|h|!h.include?('choice>') && !h.include?('case>')}.join('/<')
        item[0..3] + [newpath] + item[5..-1]
      end
    end
    return pre_select_table
  end

  def process_select node_table, option
    # 根据typepath, nspath, match和tags筛选节点
    select_table = node_table.select do|item|
      path = item[4]

      hops = (path[0]=='/' ? path : "/"+path).split('/<') # add a '/' to split '/<' for each node, then delete empty header
      hops.delete ""; hops = hops.map{|h|'<'+h}
      unless option[:typepath]
        # typepath: false && nspath: true
        # typepath: false && nspath: false
        hops = hops.map{|h|a=h.split('>');a.size>1 ? a[1].to_s : "#{a[0]}>"} # delete type in path unless node has no name
        hops = hops.map{|h|h.sub('{/','').sub('}','').split('/')}.flatten # flatten augment path
        hops = hops.map{|h|a=h.split(':');a.size>1 ? a[1].to_s : a[0]} unless option[:nspath] # delete namespace in path for each node
      else
        # typepath: true && nspath: true
        # typepath: true && nspath: false
        # type-prefix in path by-default, ns-prefix maybe exist or not, :nspath just make it notable
        unless option[:nspath]
          hops = hops.map do|h|
            rtype, rest = h.split('>'); type = rtype+'>'
            mid, post = rest.to_s.split('{'); tail = post ? '{'+post : ''
            left,right = mid.to_s.split(':')
            name = right ? right : left
            [type, name, tail].join
          end
        end
      end
      filter_path = hops.join("/")

      flag = if option[:match] == :all && !option[:tags].empty?
        option[:tags].inject(true){|flag, tag|flag && filter_path.include?(tag)}
      elsif option[:match] == :any && !option[:tags].empty?
        option[:tags].inject(false){|flag,tag|flag || filter_path.include?(tag)}
      else
        true # 不满足match和tags筛选条件直接跳过
      end
    end
    return select_table
  end

  def process_postselect node_table, option
    # 根据seltype, seltype筛选最后需要保留的节点
    post_select_table = node_table.select do|item|
      flag = true
      flag = flag && option[:seltype].include?(item[2]) unless option[:seltype].empty? # 符合节点词汇表
      option[:seltag].each do|seltag|
        flag = flag && item[6].include?('[M]') if seltag.include?('[M]')
        flag = flag && item[6].include?('[R]') if seltag.include?('[R]')
        if seltag.include?('[K]')
          keys = seltag.split('{')[1].to_s.split('}')[0].split(' ')
          kis = item[6].find{|i|i.include?('[K]')}.to_s
          flag = flag && keys.inject(false){|f,k|f || kis.include?(k)}
        end
        if seltag.include?('[U]')
          uses = eval(seltag.split(':')[1].to_s) # should be an array
          flag = flag && uses.inject(false){|f,u|f || item[5].to_s.include?(u)}
        end
      end
      flag
    end.uniq
    return post_select_table
  end

  def process_finaltable node_table, all_node_table, option
    process_table = node_table.map do|item|
      process_path = make_selpath(item[4], option[:type], option[:namespace])
      process_path = process_path.sub(option[:prefix].to_s, '$PREFIX') if option[:prefix] && !option[:prefix].to_s.empty?
      abstract = option[:abstract] ? "<#{item[2]}> #{item[3]} "+(item[6]+ (item[-2].empty? ? [] : ["[U]:"+item[-2].to_s]) ).join(' ') : nil
      doc = option[:doc] ? JSON.pretty_generate(self.documentize(item[0], namespace: option[:namespace])) : nil
      
      if option[:child]
        subdocs = item[0].elements.inject([]) do|ses,elem|
          ses << all_node_table.find{|a|a[0].object_id==elem.object_id}
        end.compact.map{|s|make_selpath(s[4], option[:type], option[:namespace])}.join("\n")
        doc = doc ? doc+"\n"+"sub-nodes:\n#{subdocs}" : "sub-nodes:\n#{subdocs}"
      end

      # <<< item: [0]node-obj, [1]node-ns, [2]node-type, [3]node-name, [4]full-path, [5]ref-table, [6]tags
      # ||| (ns, type, name, ref) >=> abstract
      # >>> proc: [0]node-obj, [1]node-path, [2]node-abs, [3]node-doc
      [ item[0], process_path, abstract, doc].compact
    end
    return process_table
  end

end
