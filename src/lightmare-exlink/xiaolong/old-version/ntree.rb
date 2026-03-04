#coding:utf-8
require 'yaml'
require 'json'

# <<THE NODE-MAPPING STRUCTURE OF YANG MODEL>>
# [NODE_NAME]:                    <---- name
#   [TYPE]: [SPEC]                <-+-- body|setting
#   properties:                     |
#     [SUBNODE.name]:               |
#       $ref: [ANOTHERNODE.index]   |
#     [ATTR]:                       |
#       [VAL]                     <-+
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
    if self.empty? and !self.setting['properties']
      sdoc = "PH:#{@@counter}"
      @@counter += 1
      return flag==:only ? sdoc : {self.name=>sdoc}
    end

    pdoc = {}
    self.setting['properties'].each do|k,v|
      pdoc[k] = "PH:#{@@counter}"
      @@counter += 1
    end if self.setting['properties']

    fdoc = self.inject({}) do|doc, kv|
      key, sub = kv
      if sub.instance_of?(Tree)
        doc.merge!(sub.to_doc())
      elsif sub.instance_of?(Array)
        doc.merge!(key=>sub.map{|s|s.to_doc(:only)})
      else
        doc.merge!(sub.to_doc(:only))
      end
      doc
    end

    pdoc.merge! fdoc
    return flag==:only ? pdoc : {self.name => pdoc}
  end
end


module XiaoLong
  module Northbound
    VERSION = '0.3.0'

    module_function

    def build modelpath, formatter=:json
      option = {json: [JSON,:parse], yaml: [YAML, :load]}
      raise "Paser Error: #{formatter} not found." unless option[formatter]
      document = option[formatter].first.send option[formatter].last, (File.read modelpath)
      pool = []

      pool = document['definitions'].inject([]) do|pool,definition|
        name, body = definition
        node = Tree.init
        node.name, node.index, node.abspath, node.setting = name, "#/definitions/#{name}", "#/definitions/#{name}", body
        pool << node
        pool
      end if document['definitions']

      pool = document['components']['schemas'].inject([]) do|pool,definition|
        name, body = definition
        node = Tree.init
        node.name, node.index, node.abspath, node.setting = name, "#/components/schemas/#{name}", "#/components/schemas/#{name}", body
        pool << node
        pool
      end if document['components'] and document['components']['schemas']

      # subnode searching
      topologic = pool.inject([]) do|topologic,node|
        if node.setting['properties']

          # subnode: node --($ref)--> subnode
          subindexes = node.setting['properties'].values.map{|r|r['$ref']}.compact
          subindexes.each do|subindex|
            subnodes = pool.select{|n|n.index==subindex}
            raise "重名节点:#{subindex}" if subnodes.size>1

            subname = node.setting['properties'].keys.find{|k|node.setting['properties'][k]['$ref']==subindex}
            if subname==subindex
              topologic << [node.index, subnodes.first.index]
            else # property_name =/= $ref
              subnode = subnodes.first.clone
              subnode.name, subnode.index, subnode.abspath = subname, "#{node.index}/#{subname}", "#{node.index}/#{subname}"
              pool << subnode
              topologic << [node.index, subnode.index]
              topologic << [subnodes.first.index, :TEMPLATE_ONLY]
            end
          end

          # subnode: node --item($ref)--> [subnode]
          sublistidx = node.setting['properties'].values.map{|r|r['items'] ? r['items']['$ref'] : nil}.compact
          sublistidx.each do|subindex|
            subnodes = pool.select{|n|n.index==subindex}
            raise "重名节点:#{subindex}" if subnodes.size>1

            subname = node.setting['properties'].keys.find do|k|
              if node.setting['properties'][k]['items']
                node.setting['properties'][k]['items']['$ref']==subindex
              else
                node.setting['properties'][k]['$ref']==subindex
              end
            end
            
            if subname==subindex
              topologic << [node.index, [subnodes.first.index]]
            else # property_name =/= $ref
              subnode = subnodes.first.clone
              subnode.name, subnode.index, subnode.abspath = subname, "#{node.index}/#{subname}", "#{node.index}/#{subname}"
              pool << subnode
              topologic << [node.index, [subnode.index]]
              topologic << [subnodes.first.index, :TEMPLATE_ONLY]
            end
          end

        end
        topologic
      end

      # build topologic
      topologic.select{|t|t[1]!=:TEMPLATE_ONLY}.each do|topo|
        sidx, eidx = topo
        snode = pool.find{|n|n.index==sidx}

        if eidx.instance_of?(Array) # [node]
          enode = pool.find{|n|n.index==eidx[0]}
          snode["#{enode.name}"] = [enode]
        else # node
          enode = pool.find{|n|n.index==eidx}
          unless enode;p "#{eidx}"  ;pool.map{|n|pp n.index};end
          snode["#{enode.name}"] = enode
        end
      end

      return pool
    end
  end
end
