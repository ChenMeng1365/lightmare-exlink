#coding:utf-8

module YBehave

  #####################################################################################################
  # cache                                                                                             #
  #####################################################################################################

  def self.prefix
    @@__yb_prefixes__ ||= {}
    return @@__yb_prefixes__
  end

  def self.nick_prefix
    @@__yb_nick_prefixes__ ||= {}
    return @@__yb_nick_prefixes__
  end

  def self.modules
    @@__yb_modules__ ||= {}
    return @@__yb_modules__
  end

  def self.groups
    @@__yb_groups__ ||= {}
    return @@__yb_groups__
  end

  def self.uses
    @@__yb_uses__ ||= []
    return @@__yb_uses__
  end

  def self.augment
    @@__yb_augment__ ||= []
    return @@__yb_augment__
  end

  def self.augments
    @@__yb_augments__ ||= []
    return @@__yb_augments__
  end

  def self.hops
    @@__yb_hops__ ||= []
    return @@__yb_hops__
  end

  def self.hops= what
    @@__yb_hops__ = what
    return @@__yb_hops__
  end

  def tag *args, &block
    block = lambda{|n|@attributes['name']} unless block
    @tag = block.call(args)
  end

  #####################################################################################################
  # element                                                                                           #
  #####################################################################################################

  # shortcut
  def n;@name;end
  def a(*keys);keys.map{|key|@attributes[key]}.join(',');end

  def modial
    return @module if @module

    @module = @attributes['name'] if !@parent && @name=='module'
    if elem = @elements.find{|e|e.name=='prefix'}
      @prefix = elem.attributes['value']
    end

    if !@parent && @name=='submodule'
      elem = @elements.find{|e|e.name=='belongs-to'}
      elem_prefix = elem.elements.find{|e|e.name=='prefix'}
      @module = elem.attributes['module']
      @prefix = elem_prefix.attributes['value']
    end

    @module = @parent.modial()    if @parent && !@module
    return @module
  end

  def prefix
    return @prefix if @prefix
    @module = modial()
    @prefix = YBehave.prefix[@module] if YBehave.prefix[@module]
    return @prefix
  end

  # behave: module regist its name as a prefix on global
  def regist_module
    if @name=='module'
      @module = modial()
      elem_prefix = @elements.find{|e|e.name=='prefix'}
      index = elem_prefix ? elem_prefix.attributes['value'] : @attributes['name']

      YBehave.prefix[@module]  =   index
      YBehave.prefix[index]    =   @module
      YBehave.modules[@module] ||= []
      YBehave.modules[index]   ||= []
      YBehave.modules[@module] <<  self
      YBehave.modules[index]   <<  self
    end

    if @name=='submodule'
      elem = @elements.find{|e|e.name=='belongs-to'}
      elem_prefix = elem.elements.find{|e|e.name=='prefix'}
      @module = elem.attributes['module']
      index = elem_prefix.attributes['value']
      # puts "<links>#{YBehave.prefix[@module]}<=>#{YBehave.prefix[index]}</links>" if  YBehave.prefix[@module] || YBehave.prefix[index]

      YBehave.prefix[@module]   =   index   unless YBehave.prefix[@module]
      YBehave.prefix[index]     =   @module unless YBehave.prefix[index]
      YBehave.modules[@module]  ||= []
      YBehave.modules[index]    ||= []
      YBehave.modules[@module]  <<  self
      YBehave.modules[index]    <<  self
    end

    elems = @elements.select{|e|e.name=='import'}
    elems.each do|elem|
      elem_prefix = elem.elements.find{|e|e.name=='prefix'}
      YBehave.nick_prefix[ elem_prefix.attributes['value'] ] = elem.attributes['module']
    end
  end

  # behave: grouping regist its name as a group in list
  def regist_group
    if @name=='grouping'
      @module = modial()
      YBehave.groups[@module] ||= {}
      YBehave.groups[@module][@attributes['name']] = self
    end
  end

  # behave: uses mapping regist
  def regist_uses
    if @name=='uses'
      desc = @attributes['name'].split(':')
      prefix = desc.size>1 ? desc[0] : nil
      groups = desc.size>1 ? desc[1] : desc[0]
      YBehave.uses << [prefix, groups, self.parent]
    end
  end

  # behave: augments regist
  def regist_augment
    if @name=='augment'
      desc = @attributes['target-node'].split('/')
      desc.delete ""
      YBehave.augment << [self]+desc.map{|item|prefix,name=item.split(':');[prefix,name]}
    end
  end

  #####################################################################################################
  # reference                                                                                         #
  #####################################################################################################

  # behave: make references between statement:include, statement:belongs-to, and statement:uses(statement:import)
  def self.make_references
    # statement:import/prefix
    YBehave.nick_prefix.each do|npfx, pfx|
      if YBehave.modules[pfx]
        YBehave.prefix[npfx]  =   pfx
        YBehave.modules[npfx] ||= []
        YBehave.modules[npfx] +=  YBehave.modules[pfx]
        YBehave.modules[npfx].uniq!
      end
    end

    YBehave.modules.each do|key, mods|
      basemod = mods.find{|mod|mod.attributes['name']==mod.module && mod.name=='module'}
      raise "[ERROR]No base module #{key} found." unless basemod
      mods.each do|mod| if mod.name=='submodule'
        mod.prev << basemod # statement:belongs-to
        basemod.next << mod # statement:include
        # puts "#{key} #{mod.attributes['name']} #{mod.module}"
      end end
    end
    
    YBehave.uses.each do|uses|
      prefix, groupname, user = uses
      module_name = YBehave.prefix[ (prefix ? prefix : user.prefix) ]
      if mods = YBehave.groups[module_name]
        if grouping = mods[groupname]
          user.next << grouping # statement:uses
          grouping.prev << user
        else
          warn "[WARN]No grouping name found when <#{user.name}>#{user.modial}:#{user.attributes['name']} use #{groupname}."
        end
      else
        # openconfig process later
        warn "[WARN]No prefix #{prefix} found when <#{user.name}>#{user.modial}:#{user.attributes['name']} use #{groupname}." unless user.modial.include?('openconfig')
      end
    end
  end

  # behave: make augments to old tree
  def self.make_augments
    YBehave.augment.each do|augment|
      node, route = augment[0], augment[1..-1]
      node_path = node.a('target-node')[1..-1].split('/').map{|hop|ht=hop.split(':'); ht.size>1 ? ht[1] : ht[0]}.join('/')
      hops = []; num = 0

      $report||=[]; $report << "augment节点路径:\n#{node_path}\n#{node.a('target-node')[1..-1]}" << ""
      
      route.each do|item|
        prefix, name = item
        module_name = YBehave.prefix[prefix]
        if models = YBehave.modules[module_name]
          # $report << "#{num}:\nNODE: #{name}\nLINK: #{prefix}==>#{module_name}(#{models.map{|m|m.a('name')}.join(',')})"

          nodes = models.inject([]) do|nodes, model|
            nodes + YTree.seek(model){|e|e}
          end.compact.uniq.select do|i| # ☆ 筛选接收端节点
            (i.a('name')==name) # && ['container','list','choice','case'].include?(i.n)
          end

          cand_node_paths = nodes.map{|n|
            nseq = n.rooting[1..-1]
            npath = nseq.map{|z| # ☆ 去掉module/submodule
              z.n=='augment' ?
              z.a('target-node')[1..-1].split('/').map{|hop|ht=hop.split(':'); ht.size>1 ? ht[1] : ht[0]}.join('/') :
              "#{z.a 'name'}"
            }.join("/")
            fpath = nseq.map{|z|
              z.n=='augment' ?
              "<augment>{#{z.a('target-node')[1..-1]}}" :
              "<#{z.n}>#{z.a('name')}"
            }.join("/")
            [npath, fpath, n]
          }.select{|ninfo|
            npath,fpath,n=ninfo
            node_path.include?(npath) && #( # ☆ 以augment和节点路径匹配全路径来判断是否符合要求 [???]
            npath.count('/')==num# || npath.count('/')==0 ) # ☆ 跳数一致或从头计数 [???]
            # ☆ uses grouping断路怎么办 [???]
          }
          hops << cand_node_paths.map{|ninfo|npath,fpath,n=ninfo;n}
          num += 1

          # $report << cand_node_paths.map{|ninfo|npath,fpath,n=ninfo;"PATH: #{fpath}"}.join("\n") << "CandiPathNum: #{cand_node_paths.size}" << ''
        else
          warn "[WARN]No prefix #{route} found when augment at #{item.join(':')}."
          # $report << "[WARN]No prefix #{prefix} found when augment at #{item.join(':')}."  << ""
        end
      end

      if hops.size==num && hops.last && hops.last.last # ☆ (不)完全路径
        easy_path = hops.last.last.rooting.map{|n|n.a 'name'}.join('/')
        type_path = hops.last.last.rooting.map{|n|"<#{n.name}>#{n.a 'name'}"}.join('/')
        $report << type_path << ''
        YBehave.augments << [ node.a('target-node'), node_path, type_path, easy_path, hops.last.last ]
      else
        $report << 'NO-RESULT'
      end

      # ★ 不能添加实连接, 搜索域会变大
      # hops[1..-1].each_with_index do|hop,idx|
      #   last_hop = hops[idx]
      #   last_hop.each do|parent|
      #     hop.each do|child|
      #       parent.next << child
      #       child.prev << parent
      #     end unless hop.empty?
      #   end if last_hop && !last_hop.empty?
      # end unless hops.empty?

      $report << '------------'
    end
  end

  #####################################################################################################
  # trace                                                                                             #
  #####################################################################################################

  def path *args, &block
    pazz = []
    pazz = self.parent.path(*args, &block) if @parent
    pazz.push tag(*args, &block)
    return pazz
  end

  def rooting hops=[]
    @hops = hops
    @hops.unshift self
    @hops = self.parent.rooting(@hops) if @parent
    return @hops
  end

  def routing hops=[]
    myhops = hops.clone
    myhops.unshift self
    unless @prev.empty?
      @prev.each do|prenode|
        prenode.routing(myhops)
      end
    else
      YBehave.hops << myhops.clone
    end
    return myhops
  end

  def [] *indexes, &block
    hops, current = [], self
    indexes.each do|index|
      elem = current ? current.next.find{|elem|block.call(elem)==index} : nil
      hops << elem
      current = elem
    end
    return hops
  end

  def trace route, &block
    self[*route.split('/'), &block]
  end
end

class XmlNode
  include YBehave

  attr_accessor :module
  attr_accessor :hops # 从根出发的节点路径, 一次rooting/routing持续保有路径, 层次变动重新计算

  alias :old_initialize :initialize
  def initialize(option = {})
    old_initialize(option)
    regist_group    if ['grouping'].include?(@name)
    regist_uses     if ['uses'].include?(@name)
    regist_augment  if ['augment'].include?(@name)
  end
end

module YTree
  module_function
  def cond_or(a,b); a||b;end
  def cond_and(a,b);a&&b;end

  def seek_path models, query
    node_list = models.inject([]) do|node_list, model|
      part_list = YTree.seek(model){|e|e}.compact.uniq
      part_list = part_list.select{|n|
        flag = true
        if query['target-node']
          flag &&= (
            n.n==(query['target-node']['type'] ? query['target-node']['type'] : 'leaf') || 
            n.n==(query['target-node']['type'] ? query['target-node']['type'] : 'leaf-list')
          )
          flag &&= n.a('name').include?(query['target-node']['name']) if query['target-node']['name']
        end
        flag
      }
      node_list + part_list
    end.uniq

    node_list += YBehave.augments.select{|auginfo|
      p1,p2,p3,p4,n=auginfo
      flag = query['path'] ? query['path'].inject(false){|flag,fragment|flag||[p1,p2,p3,p4].join('{:}').include?(fragment)} : false
    }.map{|auginfo|p1,p2,p3,p4,n=auginfo;n}
    
    relay_list = node_list.inject([]) do|relay_list, node|
      part_list = YTree.route(node){|ne|ne}
      if query['relay-node']
        query['relay-node'].each do|relay|
          part_list = part_list.select{|rt|rt[0..-2].inject(false){|flag,rn|flag || rn.n==relay['type']}} if relay['type']
          part_list = part_list.select{|rt|rt[0..-2].inject(false){|flag,rn|flag || rn.a('name').include?(relay['name'])}} if relay['name']
        end
      end
      relay_list + part_list
    end.uniq

    route_list = relay_list.inject([]) do|route_list, route|
      path = (
        query['option'].include?("type") ? route.map{|node|"<#{node.n}>#{node.n=='augment' ? "{"+node.a('target-node')+"}" : (node.n.include?('list') ? node.a('name')+"/*" : node.a('name'))}"} : route.map{|node|node.n=='augment' ? "#{node.a('target-node')[1..-1].split('/').map{|hop|ht=hop.split(':'); ht.size>1 ? ht[1] : ht[0]}.join('/')}" : (node.n.include?('list') ? node.a('name')+"/*" : node.a('name'))}
      ).join("/")
      init_val = query['option'].include?('cond:or') ? false : true
      operator = query['option'].include?('cond:or') ? :cond_or : :cond_and
      flag = query['path'].inject(init_val) do|flag, fragment|
        YTree.send(operator, flag, path.include?(fragment))
      end
      route_list << (flag ? route : nil)
    end.compact
    
    show_list = route_list.map do|route|
      sroute = route.map{|node|
        route.index(node)==1 && node.n=='grouping' ? node : ( # grouping在路径开头保留, 非路径开头且无type则删除
          query['option'].include?("type") ? node : (["choice","case","grouping"].include?(node.n) ? nil : node)
        )
      }.compact
      path = (
        query['option'].include?("type") ? sroute.map{|node|"<#{node.n}>#{node.n=='augment' ? "{"+node.a('target-node')+"}" : (node.n.include?('list') ? node.a('name')+"/*" : node.a('name'))}"} : sroute.map{|node|node.n=='augment' ? "#{node.a('target-node')[1..-1].split('/').map{|hop|ht=hop.split(':'); ht.size>1 ? ht[1] : ht[0]}.join('/')}" : (node.n.include?('list') ? node.a('name')+"/*" : node.a('name'))}
      ).join("/")
      doc = (
        query['option'].include?("doc") ? JSON.pretty_generate(YTree.documentize(route[-1])) : nil
      )
      [path,doc].compact
    end

    puts "筛选终端节点: #{node_list.size}", "筛选中间节点: #{relay_list.size}", "筛选节点路径: #{route_list.size}"
    return show_list
  end
end