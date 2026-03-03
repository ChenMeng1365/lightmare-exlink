#coding:utf-8
require 'yaml'
require 'json'

=begin
<<THE NODE-MAPPING STRUCTURE OF YANG MODEL>>
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

class Tree
  attr_accessor :name     # [NODE_NAME]
  attr_accessor :index    # 全部是definitions的子节点,统一定义在三层,如果被引用格式是#/definitions/[NODE_NAME]
  attr_accessor :abspath  # 绝对路径(暂时没有构建)
  attr_accessor :setting  # 设定参数,用于模型文档<=>原生模型实例(模型实例≠模型消息实例)

  def self.make default={}
    option = {counter: 0, level: 0, depth: 255}.merge default
    @@counter = option[:counter] if option[:counter]
    @@depth = option[:depth] if option[:depth]
    @@level = option[:level] if option[:level]
  end

  def to_doc flag=:not_only
    if @@level > @@depth
      @@level -= 1
      return flag==:only ? '...' : {self.name=>'...'}
    end

    if self.empty?
      sdoc = "PH:#{@@counter}"
      @@counter += 1
      @@level -= 1
      return flag==:only ? sdoc : {self.name=>sdoc}
    end

    pdoc = {}
    self.setting.each do|k,v|
      next if k=='properties'
      next if k=='description'
      pdoc[k] = "PH:#{@@counter}"
      @@counter += 1
    end if self.setting

    fdoc = self.inject({}) do|doc, kv|
      key, sub = kv
      @@level += 1
      if sub.instance_of?(Tree)
        doc.merge!(sub.to_doc())
      elsif sub.instance_of?(Array)
        doc.merge!(key=>sub.map{|s|
          s.instance_of?(Array) ? s.map{|si|si.to_doc(:only)} : s.to_doc(:only)
        })
      else
        doc.merge!(sub.to_doc(:only))
      end
      doc
    end

    pdoc.merge! fdoc
    @@level -= 1
    return flag==:only ? pdoc : {self.name => pdoc}
  end
end


module XiaoLong
  module Southbound
    VERSION = '0.3.0'

    module_function

    def build_topologic node,pool
      if node.setting

        # subnode: node --(property-direct)--> subnode
        node.setting['properties'].each do|subname, subsetting|
          subnode = Tree.init
          subnode.name, subnode.index, subnode.abspath, subnode.setting = subname, "#{node.index}/#{subname}", "#{node.index}/#{subname}", subsetting
          
          if subsetting['items'] # node => subnode.items[subnode]
            # subnode.name = "#{subname}.items" # not show items.collection
            # subnode.index, subnode.abspath = "#{node.index}/#{node.index}", "#{node.index}/#{node.index}" # not record in route
            
            # subnode['items/allOf']=[{},{},...] => [ [ s2node1, s2node2, ... ], ... ]
            all_of_items = subsetting['items']['allOf']
            if all_of_items && all_of_items.instance_of?(Array)
              tuple = []
              all_of_items.each do|item_setting|
                item_setting.each do|sk2, sv2|
                  # $ref
                  if sk2=='$ref'
                    s2node = pool.find{|n|n.index==sv2}
                    if s2node
                      build_topologic(s2node, pool)
                      tuple << s2node
                    else
                      item = Tree.init
                      item.name, item.index, item.abspath, item.setting = sv2, "???/#{sv2}", "???/#{sv2}", {'PENDING'=>'PENDING'}
                      # build_topologic(item, pool) # no need
                      tuple << item
                      warn "Peer(#{sk2}:#{sv2}) not found, check the reference/sequence of definitions."
                    end
                  end
                  # properties=>{}
                  if sk2=='properties'
                    sv2.each do|s2k,s2v|
                      item = Tree.init
                      item.name, item.index, item.abspath, item.setting = s2k, "#{subnode.index}/#{s2k}", "#{subnode.index}/#{s2k}", s2v
                      build_topologic(item, pool)
                      tuple << item
                    end
                  end
                end  
              end
              node[subname] = [tuple]

            else # subnode.items['properties'] => [ s2node, ... ]
              subnode.setting = subsetting['items']['properties']
              subnode.setting.each do|kv, val|
                s2node = Tree.init
                s2node.name, s2node.index, s2node.abspath, s2node.setting = kv, "#{subnode.index}/#{kv}", "#{subnode.index}/#{kv}", val
                build_topologic(s2node, pool)
                subnode[kv] = s2node
              end if subnode.setting
              node[subname] = [subnode]
            end

          else # node => subnode
            node[subname] = subnode
          end

          build_topologic(subnode, pool)
          pool << subnode
        end if node.setting['properties']
      end
    end

    def build modelpath, formatter=:json
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Paser Error: #{formatter} not found." unless option[formatter]
      document = option[formatter].first.send option[formatter].last, (File.read modelpath)
      pool = []

      document['definitions'].each do|name, setting|
        node = Tree.init
        node.name, node.index, node.abspath, node.setting = name, "#/definitions/#{name}", "#/definitions/#{name}", setting
        pool << node
      end if document['definitions']

      pool.size.times.each do|idx|
        node = pool[idx]
        build_topologic(node,pool)
      end

      return pool
    end
  end

end
