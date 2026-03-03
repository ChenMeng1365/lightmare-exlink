#coding:utf-8
require 'yaml'
require 'json'

=begin
<<THE NORTHBOUND-MAPPING STRUCTURE OF YANG MODEL>>
[NODE_NAME]:                    <---- name
  [TYPE]: [SPEC]                <-+-- body|setting
  properties:                     |
    [SUBNODE.name]:               |
      $ref: [ANOTHER_NODE.index]  |
    [ATTR]:                       |
      [VAL]                     <-+
=end

=begin
<<THE SOUTHBOUND-MAPPING STRUCTURE OF YANG MODEL>>
{
  "definitions": {
    "configuration_schema": {
      "desc": "...",
      "properties": {

        "XXX": { // 内容符合XXX_schema模板
          "desc": "...",
          "properties": {
            "111": { ... },
            "222": { ... },
            "333": { ... },
          }
        },

        "YYY": { // YYY没有引用,自身是leaf
          "desc": "...",
          "type": "..."
        }

        "AAA": { // AAA为一个列表, 参照AAA_schema定义每个元素
          "desc": "...",
          "type": "array",
          "items": {
            "properties": {
              "aaa": { ... }, // 变成 "AAA": [ {"aaa": ...}, {"bbb": ...}, {"ccc": ...} ]
              "bbb": { ... },
              "ccc": { ... }
            }
          }
        },

        "BBB": { // BBB为choice, 各选项为case "aaa", case "bbb", case "ccc" // 暂时无法区分
          "desc": "...",
          "properties": {
            "aaa": { ... }, 
            "bbb": { ... },
            "ccc": { ... }
          }
        }

      }
    },

    "state_schema": { // 中兴有,华为无
      ...
    },

    "operation_schema": { // 中兴有,华为无
      ...
    },

    "XXX_schema": {
      "desc": "...",
      "properties": {
        "111": { ... },
        "222": { ... },
        "333": { ... },
      }
    },

    "AAA_schema": {
      "properties": {
        "aaa": { ... },
        "bbb": { ... },
        "ccc": { ... }
      }
    },

    "BBB": {
      "properties": {
        "aaa": { ... }, 
        "bbb": { ... },
        "ccc": { ... }
      }
    }

  }
}
=end

class XTree < XmlNode
  attr_accessor :name       # 节点名称(reader=>accessor)
  attr_accessor :subname    # 容器子项名称
  #attr_accessor :attributes# 属性线索
  attr_accessor :children   # 子节点线索
  #attr_accessor :elements  # 子节点线索(废弃)
  #attr_accessor :parent    # 父节点线索

  attr_accessor :type       # 使用ref引用节点时, 节点名称可以不和$ref相同, 以节点类型指代, 这里$ref指向节点类型, property为节点名
  attr_accessor :setting    # 设定参数,用于模型文档<=>原生模型实例(模型实例≠模型消息实例)

  attr_accessor :header     # 路由的前向头部,对于northbound-tree统一设计为#/definitions
  attr_accessor :index      # 全部是definitions的子节点,统一定义在三层,如果被引用格式是#/definitions/:type
  attr_accessor :val        # 用于实例估值

  def initialize parent, name, attrs={}
    super(parent, name, attrs)
    @val = nil
    @children = []
  end

  def route
    return [@name] unless @parent
    return [@parent.route,@name].flatten
  end

  def depth
    route.size
  end

  def randname spec=nil
    if !@subname and @name.include?("*")
      @subname = spec ? spec : (Time.new-Time.new(1970,1,1,0,0,0)).round.to_s
    end
  end

  def insight doc=false
    parent_name = self.parent ? self.parent.name : ''
    parent_id   = self.parent ? self.parent.object_id : 'nil'
    randname()
    name_mixed  = self.subname ? "[#{self.subname}]#{self.name}" : self.name
    return [
      "names: #{name_mixed}(#{self.object_id})", "index: #{self.index}", 
      "attrs: #{self.attributes.map{|kv|k,v=kv;"#{k}(#{v.object_id})"}.join(', ')}",
      # "elems: #{self.elements.map{|e|"#{e.name}(#{e.object_id})"}.join(', ')}",
      "chdrn: #{self.children.map{|e|"#{e.name}(#{e.object_id})"}.join(', ')}",
      "parnt: #{parent_name}(#{parent_id})",
      "value: #{self.val}",
      (doc ? YAML.dump(self.setting) : '')
    ]
  end

  def trace path
    return self if path.empty?
    hops = path.split('/')
    hops.delete_if{|hop|hop==''}
    next_hop = hops.shift
    subpath = hops.join('/')
    if next_hop.include?('*') and @children.size>0
      subname = (next_hop.include?('[') and next_hop.include?(']')) ? next_hop.split('[')[1].split(']')[0] : nil
      if subname
        if child = @children.find{|child|child.subname==subname}
          next_node = child
        else
          next_node = @children.first
          warn "WARN: #{self.index} find no child exactly matched `#{next_hop}`, choose the first one of child"
        end
      else
        next_node = @children.first
        warn "WARN: #{self.index} has one more children #{self.children.map{|c|c.name}.join(',')}, they should be isomerism" if @children.size>1
      end
    else
      next_node = @attributes[next_hop]
    end
    return next_node.trace(subpath) if next_node.is_a?(XmlNode)    
    raise "Routing Error on #{path}: #{self.name} --#{next_hop}--> X"
  end

  def backtrace path
    return self if path.empty?
    hops = path.split('/')
    next_hop = hops.pop # the path will be traced back
    if self.parent and ( self.parent.name==next_hop or (self.parent.name.include?('*') and next_hop.include?('*') ) )
      return self.parent.backtrace(hops.join('/'))
    else
      raise "Routing ERROR: No backroute from #{self.name} to parent via #{next_hop}."
    end
  end

  def to_index list
    randname() # to_index只对leaf-node有效, 中间的list-item不会显示, 所以randname只被动产生一次subname
    if @attributes.empty? and @children.empty? # leaf node
      list.instance_of?(Array) and list << {@index=>@val}
      list.instance_of?(Hash)  and list.merge!(@index=>@val)
    end

    if @type=='list' # list node
      succeeds = []
      @children.each do|child|
        child.to_index list
      end

    else # normal node
      succeeds = []
      @attributes.each do|prop, node|
        node.to_index list
      end
    end

    return @index
  end

  def to_doc proc=nil
    proc = lambda{|s|"PH:#{s.object_id}"} unless proc

    return {@name=>lambda{"..."}.call} if @@depth < depth
    return proc.call(self)             if (@attributes.empty? and @children.empty?)

    ndoc, pdoc = [], {}
    @attributes.each do|subname, subnode|
      pdoc.merge!(subname=>subnode.to_doc(proc))
    end
    @children.each do|child|
      ndoc << child.to_doc(proc)
    end

    return (ndoc.empty? ? pdoc : ndoc )
  end

  def to_netconf
    # @name = "#{@name}#{self.object_id}"
    if @attributes.empty? and @children.empty? # leaf node
      return @val ? "<#{@name}>#{@val}</#{@name}>" : ''
    end

    if @type=='list' # list node
      succeeds = []
      @children.each do|child|
        nc = child.to_netconf
        succeeds << (nc=='' ? '' : nc)
      end
      return succeeds.join

    else # normal node
      succeeds = []
      @attributes.each do|prop, node|
        succeeds << node.to_netconf
      end
      tag = @name.include?('*') ? @type : @name
      return succeeds.join=='' ? '' : "<#{tag}>#{succeeds.join}</#{tag}>"
    end
  end

  ################################################################################
  # 
  # global setting
  # 
  # 当实际树模型深度超过设定深度时,不进行迭代直接返回
  # 
  ################################################################################
  @@depth = 255

  def self.make setting={}
    option    = {depth: 255}.merge setting
    @@depth   = option[:depth]   if option[:depth]
  end
end


module XiaoLong
  VERSION = '0.8.0'

  module_function
  ################################################################################
  # 
  # metaphysic(doc) --(call)--> metaresolve({prop=>subdoc}, node)
  # 
  # 将Native文档对象解析为相应的文档格式, 组织成树型结构
  # 
  # asym(path, root)
  # 
  # 给定根节点, 生成相对路径的偏序结构模型
  # 
  ################################################################################
  def metaphysic doc
    root = XTree.new(nil, 'definitions')
    root.type, root.setting = 'root', doc
    root.header, root.index =  '#', "#/#{root.name}"
    if doc.is_a?(Hash)  
      doc.each do|prop, subdoc|
        metaresolve({prop=>subdoc}, root)
      end
    elsif doc.is_a?(Array)
      doc.each do|subdoc|
        metaresolve({prop=>subdoc}, root)
      end
    end
    return root
  end

  def metaresolve doc,parent,forward=false
    prop, subdoc = doc.keys.first, doc.values.first
    subnode = XTree.new(parent, prop)
    subnode.type, subnode.setting = prop, subdoc
    subnode.header, subnode.index = "#{parent.header}/#{parent.name}", "#{parent.index}/#{subnode.name}"
    parent.attributes[prop] = subnode unless forward
  
    if subdoc.is_a?(Hash)
      subnode.index = "#{parent.index}/#{subnode.name}"
      subdoc.each do|nprop, ndoc|
        metaresolve({nprop=>ndoc}, subnode)
      end
  
    elsif subdoc.is_a?(Array)
      subnode.type = 'list'
      subnode.children = []
      subdoc.each do|item|
        itemnode = XTree.new(subnode, '*') # or "#{subnode.name}*"
        itemnode.randname()
        itemnode.type, itemnode.setting = subnode.name, item # or type = '*' or 'list-item'
        itemnode.header, itemnode.index = "#{subnode.header}/#{subnode.name}", "#{subnode.index}/#{itemnode.name}"
        subnode.children << itemnode
  
        item.each do|nprop, ndoc|
          metaresolve({nprop=>ndoc}, itemnode)
        end
      end
    else
      subnode.val = subdoc
    end
    
    # puts *subnode.insight
    return subnode
  end

  def gen_root
    root = XTree.new(nil, 'definitions')
    root.type = root.name
    root.header, root.index = "#", "#/#{root.name}"
    return root
  end

  def asym path, root=nil
    hops = path.split('/')
    root = self.gen_root unless root
    current = root
    hops.each do|hop|
      if hop.include?('*')
        current.type = 'list'
        current.attributes = {} # caution
        itemname = (hop.include?('[') and hop.include?(']')) ? hop.split('[')[1].split(']')[0] : nil
        item = current.children.find{|item|item.subname==itemname}
        unless item
          item = XTree.new(current, '*')
          item.randname(itemname)
          item.type = current.name # old: hop
          item.header, item.index = "#{current.header}/#{current.name}", "#{current.index}/#{item.name}"
          current.children << item
        end
        current = item
      else
        node = current.attributes[hop]
        unless node
          node = XTree.new(current, hop)
          node.type = node.name
          node.header, node.index = "#{current.header}/#{current.name}", "#{current.index}/#{node.name}"
          current.attributes[hop] = node
        end
        current = node
      end
    end
    return current
  end


  module Northbound
    module_function

    def build_from modelpath, formatter=:yaml
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Builder Chosen Error: #{formatter} not found." unless option[formatter]
      raise "ModelPath Loading Error: #{modelpath} unreachable." unless File.exist?(modelpath)
      build(File.read(modelpath), formatter)
    end

    def build model, formatter=:yaml
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Builer Chosen Error: #{formatter} not found." unless option[formatter]
      builder, method = option[formatter]
      document = builder.send method, model

      todo, pool = {}, []
      todo.merge! document['definitions']           if document['definitions']
      todo.merge! document['components']['schemas'] if document['components'] and document['components']['schemas']

      root = XTree.new(nil, 'definitions')
      root.type, root.setting, root.header = 'root', {'properties'=>todo}, '#'
      root.index = "#{root.header}/#{root.name}"
      # pool << root

      todo.each do|type, setting|
        node = XTree.new(root, type) # the first level @name == @type
        node.type, node.setting, node.header = type, setting, '#/definitions' # the root header is '#' and name is 'definitions'
        node.index = "#{node.header}/#{node.name}"
        pool << node
      end

      build_topologic pool
      return pool
    end

    def build_topologic pool
      # topologic = []
      pool.each do|node|
        if node.setting.is_a?(Hash) and node.setting['properties']
          # case0 : if a node has no property, it's just a leaf node, no relation to other subnodes.
          # nothing to do about leaf node

          node.setting['properties'].each do|prop, subsetting|
            # case1 : node --(property)--> subnode, the property is an entity
            unless subsetting['$ref'] or subsetting['items']
              subnode = XTree.new(node, prop)
              subnode.type, subnode.setting = subnode.name, subsetting
              subnode.index, subnode.header = "#{node.index}/#{subnode.name}", "#{node.header}/#{node.name}"
              node.attributes[prop] = subnode
              pool << subnode
              # topologic << [prop, node.object_id, subnode.object_id]
            end

            # case2: node --(property)--> $ref ==> subnode
            # the $ref maybe not equal subnode.name (should be equal subnode.type except sublist.items)
            # the template subnode.index should be subnode.header/subnode.name ( ☆ searching for subnode.index )
            # the instance subnode.index should be node.index/subnode.name ( =/= subnode.header/subnode.name )
            if subsetting['$ref']
              subname, subindex = prop, subsetting['$ref']
              subnodes = pool.select{|n|n.index==subindex}
              raise "ERROR: Duplicate nodes for index:#{subindex} in node:#{node.name}.#{prop}['$ref']" if subnodes.size>1
              raise "ERROR: Undefined node for index:#{subindex} in node:#{node.name}.#{prop}['$ref']"  if subnodes.size==0
              subnode = subnodes.first.clone # type, setting no change
              subnode.name   = subname # instance name should not must be equal template name
              subnode.header = "#{node.header}/#{node.name}"
              subnode.index  = "#{node.index}/#{subnode.name}"
              node.attributes[subname] = subnode
              pool << subnode
              # topologic << [subname, node.object_id, subnode.object_id]
              # topologic << [subname, subnodes.first.object_id, :TEMPLATE_ONLY]

              subnode.attributes = {} # ☆ subnode is an instance, should not keep the relations of template
              subnode.setting.each do|sprop, ssetting|
                ssetting['properties'].each do|nprop, nsetting|
                  s2node = XTree.new(subnode, nprop)
                  s2node.type, s2node.setting = nprop, nsetting
                  s2node.header = "#{subnode.header}/#{subnode.name}"
                  s2node.index  = "#{subnode.index}/#{s2node.name}"
                  subnode.attributes[nprop] = s2node
                  pool << s2node
                  # topologic << [nprop, subnode.object_id, s2node.object_id]
                end if ssetting.is_a?(Hash) and ssetting['properties']
              end
            end

            # case3: node --(property)--> --(items)--> $ref ==> subnode(as a template)
            # the subnode is an instance of template node to be the member of list who named node.proprty
            # so the structure is :
            # node --(property)--> sublist(name=prop, type=list) --> subnode(name=*, type=sublist.name, have many setting, and number is many)
            if subsetting['items']
              unless subsetting['items']['$ref'] # node.properties.SUBNAME.items.ENTITY
                subname = prop
                subnode = XTree.new(node, subname)
                subnode.type    = 'list'
                subnode.setting = subsetting
                subnode.header  = "#{node.header}/#{node.name}"
                subnode.index   = "#{node.index}/#{subname}" # /node/subnode
                node.attributes[subname] = subnode
                pool << subnode

                sublist = XTree.new(subnode, '*')
                sublist.type, sublist.setting = subname, subsetting['items']
                sublist.header = "#{subnode.header}/#{subnode.name}"
                sublist.index  = "#{subnode.index}/#{sublist.name}" # /node/subnode/*
                subnode.children << sublist
                pool << sublist

                sublist.setting.each do|sprop, ssetting|
                  ssetting['properties'].each do|nprop, nsetting|
                    s2node = XTree.new(sublist, nprop)
                    s2node.type, s2node.setting = nprop, nsetting
                    s2node.header = "#{sublist.header}/#{sublist.name}"
                    s2node.index  = "#{sublist.index}/#{s2node.name}"
                    sublist.attributes[nprop] = s2node
                    pool << s2node
                  end if ssetting.is_a?(Hash) and ssetting['properties']
                end

              end
              if subsetting['items']['$ref'] # node.properties.SUBNAME.items.$ref
                subname, subindex = prop, subsetting['items']['$ref']
                subnodes = pool.select{|n|n.index==subindex}
                raise "ERROR: Duplicate nodes for index:#{subindex} in node:#{node.name}.#{prop}['$ref']" if subnodes.size>1
                raise "ERROR: Undefined node for index:#{subindex} in node:#{node.name}.#{prop}['$ref']"  if subnodes.size==0
                subnode = subnodes.first.clone
                subnode.name, subnode.type = subname, 'list'
                subnode.header = "#{node.header}/#{node.name}"
                subnode.index  = "#{node.index}/#{subname}" # /node/subnode
                node.attributes[subname] = subnode
                pool << subnode

                sublist = XTree.new(subnode, '*')
                sublist.type, sublist.setting = subname, subnode.setting
                sublist.header = "#{subnode.header}/#{subnode.name}"
                sublist.index  = "#{subnode.index}/#{sublist.name}" # /node/subnode/*
                subnode.attributes, subnode.children = {}, [] # ☆ subnode is an instance, should not keep the relations of template
                subnode.children << sublist
                pool << sublist
                # topologic << [subname, node.object_id, subnode.object_id]
                # topologic << ['*', subnode.object_id, sublist.object_id]
                # topologic << [subname, subnodes.first.object_id, :TEMPLATE_ONLY]

                sublist.setting.each do|sprop, ssetting|
                  ssetting['properties'].each do|nprop, nsetting|
                    s2node = XTree.new(sublist, nprop)
                    s2node.type, s2node.setting = nprop, nsetting
                    s2node.header = "#{sublist.header}/#{sublist.name}"
                    s2node.index  = "#{sublist.index}/#{s2node.name}"
                    sublist.attributes[nprop] = s2node
                    pool << s2node
                    # topologic << [nprop, sublist.object_id, s2node.object_id]
                  end if ssetting.is_a?(Hash) and ssetting['properties']
                end
              end
            end

          end

        end
      end
      # return topologic
    end
  end


  module Southbound
    module_function

    def build_from modelpath, formatter=:json
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Builder Chosen Error: #{formatter} not found." unless option[formatter]
      raise "ModelPath Loading Error: #{modelpath} unreachable." unless File.exist?(modelpath)
      build(File.read(modelpath), formatter)
    end

    def build model, formatter=:json
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Builder Chosen Error: #{formatter} not found." unless option[formatter]
      builder, method = option[formatter]
      document = builder.send method, model

      todo, pool = {}, []
      todo.merge! document['definitions']           if document['definitions']
      todo.merge! document['components']['schemas'] if document['components'] and document['components']['schemas']

      root = XTree.new(nil, 'definitions')
      root.type, root.setting, root.header = 'root', {'properties'=>todo}, '#'
      root.index = "#{root.header}/#{root.name}"
      # pool << root

      todo.each do|type, setting|
        node = XTree.new(root, type) # the first level @name == @type
        node.type, node.setting, node.header = type, setting, '#/definitions' # the root header is '#' and name is 'definitions'
        node.index = "#{node.header}/#{node.name}"
        pool << node
      end

      pool.each do|node|
        build_topologic(node,pool)
      end
      return pool
    end

    def build_allof node, pool, setting
      # in this case, node will be node-list, sublist(s) will be node-list-item, each sublist(s) will mount many subnodes
      # node --(allOf)--> sublist --(property/$ref)--> subnode
      # node --(items.allOf)--> sublist --(property/$ref)--> subnode
      all_of_items = setting
      if all_of_items && all_of_items.instance_of?(Array)

        all_of_items.each do|item_setting|
          sublist = XTree.new(node,'*') # ☆ sublist-item.name=='*' # or 'allOf*'
          sublist.type, sublist.setting = node.name, item_setting
          sublist.index, sublist.header = "#{node.index}/#{sublist.name}", "#{node.header}/#{node.name}"
          node.children << sublist # ☆ not node.attributes['items'] = sublist, because sublist will have many attributes in template
          # tuple = []
          item_setting.each do|sk2, sv2|

            if sk2=='$ref' # $ref refers to another node
              subnode = pool.find{|n|n.index.gsub("/*","")==sv2} # "/*" => ""
              if subnode # found definition
                item = subnode.clone # @name, @type, @setting not change
                item.index, item.header = "#{sublist.index}/#{item.name}", "#{sublist.header}/#{sublist.name}"
                build_topologic(item, pool)
                sublist.attributes[item.name] = item
                item.parent = sublist
              else # not found $ref
                item = XTree.new(sublist, sv2)
                item.type, item.setting = item.name, {'PENDING'=>'TODO'}
                item.index, item.header = "???/#{item.name}", "#{sublist.header}/#{sublist.name}"
                # build_topologic(item, pool) # no need
                sublist.attributes[item.name] = item
                warn "WARN: Node(#{sk2}:#{sv2}) not found, check the reference/sequence of definitions."
              end
              # tuple << item
            end

            if sk2=='properties' # properties=>{}
              sv2.each do|s2k,s2v|
                item = XTree.new(sublist, s2k)
                item.type, item.setting = item.name, s2v
                item.index, item.header = "#{sublist.index}/#{s2k}", "#{sublist.header}/#{sublist.name}"
                build_topologic(item, pool)
                sublist.attributes[sk2] = item
                # tuple << item
              end
            end

          end
          # sublist.children << tuple # sublist.type = 'l2-list' ???
        end
      end
    end

    def build_topologic node, pool
      if node.setting
        # node --(property)--> subnode(s) ==> subitem(s).attributes{ s2node, ... }
        node.setting['properties'].each do|subname, subsetting|
          # node --(property)--> subnode(sublist) --> sublist-item(*).attributes{ s2node1, s2node2, ... }
          if subsetting['items']
            subnode = XTree.new(node, subname)
            subnode.type, subnode.setting = 'list', subsetting # ☆ subnode.type=='list'
            subnode.index, subnode.header = "#{node.index}/#{subnode.name}", "#{node.header}/#{node.name}"
            node.attributes[subname] = subnode

            # sublist-item --(s2prop)--> s2node
            if subsetting['items']['properties']
              sublist = XTree.new(subnode,'*') # ☆ sublist-item.name=='*'
              sublist.type, sublist.setting = subname, subsetting['items']['properties'] # ☆ sublist-item.type==subnode.name
              sublist.index, sublist.header = "#{subnode.index}/#{sublist.name}", "#{subnode.header}/#{subnode.name}"
              subnode.children << sublist # ☆ not subnode.attributes['items'] = sublist
              sublist.setting.each do|kv, val|
                s2node = XTree.new(sublist, kv)
                s2node.type, s2node.setting = kv, val
                s2node.index, s2node.header = "#{sublist.index}/#{s2node.name}", "#{sublist.header}/#{sublist.name}"
                sublist.attributes[kv] = s2node
                build_topologic(s2node, pool)
                pool << s2node
              end
              build_topologic(sublist, pool)
              pool << sublist # only one sublist item in template formation

            # sublist-item --(s2prop/$ref)(s)--> s2node
            elsif subsetting['items']['allOf']
              build_allof(subnode, pool, subsetting['items']['allOf'])
            end

            build_topologic(subnode, pool)
            pool << subnode

          else # node --(property)--> subnode
            subnode = XTree.new(node, subname)
            subnode.type, subnode.setting = subname , subsetting
            subnode.index, subnode.header = "#{node.index}/#{subname}", "#{node.header}/#{node.name}"
            node.attributes[subname] = subnode
            build_topologic(subnode, pool)
            pool << subnode
          end

        end if node.setting['properties'] && node.setting['properties'].is_a?(Hash)

        # node --> sublist --(property/$ref)(s)--> subnode
        if node.setting['allOf']
          node.type = 'list' # ☆ node.type=='list'
          build_allof(node, pool, node.setting['allOf']) 
        end
      end
    end
  end
end
