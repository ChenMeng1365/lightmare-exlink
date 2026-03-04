#coding:utf-8
require 'yaml'
require 'json'

module YTree
  module_function

  # 定义并使用检查列表, 列表元素为节点类型
  def self.list= list
    @__ycheck_list__ = list
  end

  def self.list
    @__ycheck_list__ ||= %w{
      typedef enum leaf leaf-list container grouping augment refine list choice case
    }
    return @__ycheck_list__
  end

  def self.debug= log
    @__ycheck_log__ ||= []
    @__ycheck_log__ += log
  end

  def self.debug
    @__ycheck_log__ ||= []
  end

  def self.in? &block
    @__ycheck_list__.include?(block.call)
  end

  def self.out? &block
    !@__ycheck_list__.include?(block.call)
  end

  # 打印节点路径, 配合XmlNode#rooting使用
  def self.path node, &block
    node.rooting.map(&block).join('/')
  end

  # 制作节点文档, 不同于XmlNode#to_a
  def self.documentize node, args={}
    option = {raw: false, namespace: false}.merge(args)
    # raw: {T:简化三元组打印, F:语义检查打印}
    # namespace: {T:带命名空间, F:不带命名空间}

    # 对简单语义的节点调用YCheck中预定的方法来解析语义生成文档
    return ycheck(node, node.name) if ycheck?(node.name) && !option[:raw]

    # 不满足简单语义或强制原样格式的节点按简化三元组样式打印
    base = node.attributes
    base.delete :namespace if base[:namespace] && !option[:namespace]
    base.merge! 'type'=>node.name
    base['success'] = []
    node.elements.each do|subn|
      base['success'] << self.documentize(subn, option)
    end
    base.delete 'success' if base['success'].empty?
    return base
  end

  # 从一个节点遍历其所有子节点, 给出每个节点的摘要信息
  def self.walk node, list=[], &gen_info
    list << gen_info.call(node)
    node.elements.each do|subnode|
      self.walk(subnode, list, &gen_info)
    end
    return list
  end
end

# ::Kernel 等效于send(signal,node), 做了非常规命名处理
# 由于重名覆盖机制, 小心命名为`signal`的节点触发YCheck.send(:signal, node)
def ycheck node, signal
  begin
    YCheck.send signal.gsub('-','_').to_sym, node
  rescue NoMethodError => err
    YCheck.send ('_'+signal.gsub('-','_')).to_sym, node
  end
end

def ycheck? signal
  check = YCheck.respond_to? signal.gsub('-','_').to_sym
  check = YCheck.respond_to? ('_'+signal.gsub('-','_')).to_sym unless check
  unless check
    log = "WARN: Unknown node-singal for checking: #{signal}"
    YTree.debug << log
    warn log if $ytree_debug
  end
  return check
end

def ycheck! node, signal
  ycheck?(signal) ? ycheck(node, signal) : nil
end

class XmlNode
  # 从根出发的节点路径, 一次rooting持续保有路径, 层次变动重新计算
  attr_reader :hops

  def rooting hops=[]
    @hops = hops
    @hops.unshift self
    @hops = self.parent.rooting(@hops) if @parent
    return @hops
  end
end
