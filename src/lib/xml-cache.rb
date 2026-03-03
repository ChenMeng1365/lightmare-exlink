#coding:utf-8
require 'rexml/parsers/sax2parser'
require 'rexml/sax2listener'
require 'rexml/document'

module XmlParser
  def self.load(filepath)
    return File.exist?(filepath) ? XmlParser.parse(open(filepath){|f| f.read}) : nil
  end

  # 三元组格式的节点：
  # [name,{attribute_name=>attribute_value},[children]]
  def self.parse(s)
    parser = REXML::Parsers::SAX2Parser.new(s)
    root,current = nil,nil
    # when check start tag
    parser.listen(:start_element) do |url, local, qname, attributes|
      current = XmlNode.new(current, local, attributes)
      current.attributes[:namespace]=url
      root ||= current
    end
    # when check end tag
    parser.listen(:end_element) do |url, local, qname, attributes|
      current = current.parent
    end
    # when check others
    parser.listen(:characters) do |text|
      t = text.strip
      if t.size > 0
          current.attributes[:text] ||=""
          current.attributes[:text] += t
      end
    end
    parser.parse
    return root
  end
end


# JSON三元组格式的XML节点
# 用来存放所有类型的XML元素
class XmlNode
  attr_reader :name
  attr_accessor :attributes,:elements,:parent
  
  # 一般用于XMLParser动态创建XmlNode
  def initialize(parent, name, attributes={})
    @parent,@name,@elements = parent,name,[]
    @attributes = {}.merge!(attributes)
    parent.elements << self if parent
  end

  def get_path
    temp = "";temp_parent = @parent
    while temp_parent && temp_parent.parent
      # 父节点不为空，且父节点不为根节点时
      (temp="";break) unless temp_parent.attributes["name"]
      temp = "#{temp_parent.attributes["name"]}/"+temp
      temp_parent = temp_parent.parent
    end
    return "" unless @attributes["name"]
    return ( temp == "" ? @attributes["name"] : temp+@attributes["name"] )
  end

  #### format ####
  # 转化为三元组格式
  def to_a
    attrs,elems = {},[]
    @attributes.each do|k,v|
      unless k == :text
        attrs[k] = v
      else
        elems += [v].flatten
      end
    end
    elems += @elements.collect{|c|c.to_a}
    [@name, attrs, elems]
  end
  
  # 转化为JSON格式字符串
  def to_json
    require 'json'
    JSON.generate(to_a)
  end
  
  # 文档结构化
  def to_doc
    doc = {}
    doc[@name] = []
    doc[@name] << @attributes #@attributes.each{|k,v|doc[name] << {k=> v}}
    @elements.each{|e|doc[@name] << e.to_doc}
    return doc
  end
  
  # 转化为YAML文档
  def to_yaml
    require 'yaml'
    to_doc.to_yaml # 等价于YAML.dump(to_doc)
    # YAML.dump( to_a )
  end

  # 转化为XML格式字符串
  def to_xml
    attrs, content = '', ''
    @attributes.each do |k,v|
      if k == :text
        content += "#{[v].flatten.join("\n")}\n"
      else
        attrs += " #{k}=\"#{v}\""
      end
    end
    return "<#{@name}#{attrs}/>\n" if @elements.size==0 && !@attributes[:text]
    @elements.each do|e|
      content += if e.is_a?(XmlNode)
        e.to_xml
      elsif e.instance_of?(String)
        "#{e}\n"
      end
    end
    return "<#{@name}#{attrs}>\n#{content}</#{@name}>\n"
  end

  #### attributes ####
  # 增加属性
  # 已存在的属性会被覆盖
  def add_attributes hash
    (@attributes[:text] ||= []) << hash[:text] if hash[:text]# 文本的特殊处理
    hash.delete(:text)
    @attributes.merge!(hash)
  end

  # 修改属性
  # 和add_attributes没区别
  def modify_attributes hash
    add_attributes hash
  end
  
  # 删除属性
  # 注意：方法名是单数
  def delete_attribute key
    @attributes.delete(key) unless key==:text # 元素的内容不删除
  end

  #### content ####
  # 增加元素的内容
  # 内容追加书写
  def add_content content
    #@attributes[:text] += content
    @elements << content
  end
  
  # 修改元素的内容
  # 原来的内容会被覆盖
  def modify_content content
    @attributes[:text] = []
    @elements.delete_if{|e|e.is_a?(String)}
    @elements << content
  end

  # 删除元素的内容
  def delete_content
    #@attributes.delete(:text)
    @elements = @elements.find_all{|c|!c.instance_of?(XmlNode)}
  end

  #### elements ####
  # 增加子元素
  # 只增加XmlNode型节点
  # 根据子元素的值决定该子元素是否可以被添加
  def add_element elem
    if elem.is_a?(XmlNode) && !@elements.include?(elem)
      @elements << elem
      elem.parent = self
    end
  end

  # 查询子元素
  def search_elements &block
    return  ( block ? @elements.find_all(&block) : [] )
  end

  # 删除子元素
  def delete_elements &block
    elems = search_elements(&block) if block
    elems.each{|elem|@elements.delete(elem)}
    return elems
  end

  # 修改子元素
  # 内涵太多，不予考虑

  #### others ####
  # 拷贝节点
  # 但是子元素不会拷贝，只保持引用关系
  def self.copy node
    duplicate=XmlNode.new(nil,node.name,node.attributes)
    duplicate.elements = Array.new(node.elements)
    duplicate
  end
end


# 组织XmlNode树状结构的模型
# 便于查询、修改XmlNode对象
class XmlModel
  attr_reader :name
  attr_accessor :context
  
  def initialize name="未命名模型"
    name = "未命名模型" if (name == nil || name == "")# 防止强制改名为空
    @name = name; @context = {}
  end

  def reset; @context = {}; end

  #### 转化方法 ####
  # 从文档中读取XML模型
  # filepath带路径名，不带扩展名，默认读XML文档(*.xml)
  # if load failed will return false, else return true
  def load filepath; convert XmlParser.load(filepath); end

  # 转换每一个元素及子元素(递归方法，内部使用)
  # flowitem是XmlNode对象
  def rebridge flowitem
    name = flowitem.name
    @context[name] ||= [] # 不存在该类型的节点，则生成该类型的空列表
    # 该节点不存在于列表中，则将该节点加入列表中
    @context[name].push(flowitem) unless @context[name].include?(flowitem)
    flowitem.elements.each{|elem|rebridge elem} # 对该节点的子元素节点如此加入
  end
  private :rebridge

  # 将XML根元素转化为XML模型的内容，返回转化状态(true/false)
  # data是XmlNode对象
  def convert data
    if data.class == XmlNode
      rebridge data
      return true # the result merge in @context
    else
      return false # @context no change
    end
  end

  # 转化特定类别的元素(递归方法，内部使用)
  # flow_item是XmlNode对象
  def rebridge_part flow_item,item_name
    if item_name == flow_item.name # 只对特定名字的节点元素加入为工作项
      # 该节点不存在于列表中，则将该节点加入列表中
      @context[item_name].push(flow_item) unless @context[item_name].include?(flow_item)
    end
    # 对该节点的子元素节点同样判断和处理
    flow_item.elements.each{|elem| rebridge_part(elem,item_name)}
  end
  private :rebridge_part

  # 将XML根元素的部分元素转化为XML模型的内容，返回转化状态(true/false)
  # data是XmlNode对象
  # 只会转化data中类别名称为item_name的元素
  def convert_part data,item_name
    @context[item_name] ||= []
    rebridge_part data,item_name
    # 清除那些不存在的键名创建的表项
    @context.each{|k,v|@context.delete(k) if v.empty?}
    return ( @context.empty? ? false : true )
  end

  #### 元素查找 ####
  # 查找指定类别的元素集合
  def [] keyword; @context[keyword]; end

  # 查找指定条件的所有元素
  # keyword用来指定元素的类型<keyword>...</keyword>
  # 一般查找条件主要针对item.name和item.attributes
  # 不输入keyword查找所有元素
  # 查找过程是随机的（Hash），如果条件过于广泛，很难找得精确
  def find_all keyword=:all, &block
    item_set = []
    if keyword == :all
      @context.each{|key,items|item_set << items.find_all(&block) if block}
      item_set.flatten!
    else
      item_set = @context[keyword].find_all(&block) if block
    end
    return item_set
  end

  # 查询最先找到的第一个元素(XmlNode对象)
  # 除了只返回一个元素，特性和find_all类似
  def find keyword=:all, &block
    item = nil
    if keyword == :all
      @context.each do|key,items|
        item = items.find(&block) if block
        break if item
      end
    else
      item = @context[keyword].find(&block) if block
    end
    return item
  end

  #### 元素增加 ####
  # 往指定类别中添加元素
  # xmlmodel中的元素并不一定维持着完全树状的结构关系
  # add_item也可以将和XML文档中转化的完全无关的元素纳入到上下文中@context来
  # 那些没有维护树状关系的元素，在to_xml时将无法输出（如需要请自己指明其父元素）
  def add_item keyword,item
    if item.class == XmlNode
      @context[keyword] ||= []
      @context[keyword] << item unless @context[keyword].include?(item)
    end
  end

  #### 元素删除 ####
  # 删除指定类别和条件的元素
  # 必须指定元素类别(item.name)
  # 如果不指定查询条件，将不做任何改动
  def del_items keyword,&block
    item_set = []
    item_set = find_all(keyword,&block) if block
    item_set.each do |item|@context[item.name].delete(item) end
    return item_set
  end

  #### 格式输出 ####
  # root为选定的根节点，其子元素将全部转化
  # outpath可以指定路径名，不需要带扩展名
  def to_xml outpath,root
    return unless root.class == XmlNode
    header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    body = root.to_xml
    File.open("#{outpath}.xml",'w'){|f|f.puts(header+body)}
  end

  def to_json outpath,root
    return unless root.class == XmlNode
    File.open("#{outpath}.json",'w'){|f|f.puts root.to_json}
  end

  def to_yaml outpath,root
    return unless root.class == XmlNode
    File.open("#{outpath}.yaml",'w'){|f|f.puts(root.to_yaml)}
  end
end


module XMLStringChanger
  def self.to_str xml
    text = String.new(xml)
    ['&lt;','&gt;','&amp;','&apos;','&quot;'].zip(["<",">","&",%{'},%{"}]) do|xstr,str| text.gsub!(xstr,str) end
    return text
  end
  
  def self.to_xml string
    xml = String.new(string)
    # 注意：'&'要最先被替换
    ['&','<','>',%{'},%{"}].zip(['&amp;','&lt;','&gt;','&apos;','&quot;']) do|str,xstr| xml.gsub!(str,xstr) end
    return xml
  end

  def self.pretty string,indent=2
    require 'rexml/document'
    doc = REXML::Document.new(string, { :raw => :all })
    pretty_xml = ""
    doc.write(pretty_xml, indent)
    return pretty_xml
  end
end

=begin
def 转换器; XMLStringChanger; end
xml原文 = "if salary &lt; 1000 &amp;&amp; salary &gt; 500 then puts &apos;合法工资&apos; else raise &quot;你的收入不对&quot; end"
xml转意文= 转换器.to_str(xml原文)
xml转回文 = 转换器.to_xml(xml转意文)
puts xml转意文,xml转回文
=end

# class XmlNode
#   # 另一种文档格式——类似散列对象，使用时引用顺序在XmlNode之后
#   # doc = {
#   #   obj: 
#   #     '-attr': val,
#   #     '#text': text,
#   #     obj: {
#   #       ...
#   #     },
#   #     ...
#   # }
#   def to_doc
#     doc = {}
#     @attributes.each do|k,v|
#       h = k==:text ? '#' : '-'
#       doc["#{h}#{k}"] = v 
#     end
#     @elements.each do|elem|
#       doc.merge! elem.to_doc
#     end
#     return {@name => doc}
#   end

#   def to_json
#     require 'json'
#     JSON.generate(to_doc)
#   end

#   def to_yaml
#     to_doc.to_yaml
#   end

# end
