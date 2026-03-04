#coding:utf-8
# REPLICA FROM IMDOC/XMLUTILS
%w{rexml/parsers/sax2parser rexml/sax2listener rexml/document json yaml}.each{|mod|require mod}

class XmlNode
  attr_accessor :name, :attributes, :elements, :parent, :next, :prev

  def initialize(option = {})
    args = {parent: nil, attributes: {}, elements: [], prev: [], next: []}.merge(option)
    @name = args[:name] || "OID:#{self.object_id}"
    @attributes = args[:attributes]
    @parent, @elements, @prev, @next = args[:parent], args[:elements], args[:prev], args[:next]
    
    if @parent
      @prev << @parent unless @prev.include?(@parent)
      @parent.elements << self unless @parent.elements.include?(self)
      @parent.next << self unless @parent.next.include?(self)
    end
  end

  #####################################################################################################
  # format                                                                                            #
  #####################################################################################################

  # 三元组 ([name, attributes, [name, attributes, ...]])
  def to_triad
    attrs,elems = {},[]
    @attributes.each do|k,v|
      unless k == :text
        attrs[k] = v
      else
        elems += [v].flatten
      end
    end
    elems += @elements.map{|c|c.to_triad}
    [@name, attrs, elems]
  end
  alias :to_a :to_triad

  # 文档化 ({name: [attributes, {name: [...]}]})
  def to_doc
    doc = {}
    doc[@name] = []
    doc[@name] << @attributes #@attributes.each{|k,v|doc[@name] << {k=> v}}
    @elements.each{|e|doc[@name] << e.to_doc}
    return doc
  end

  # 对象化 (like js: {obj: {'-attr': val, '#text': text, obj: {...}}})
  def to_obj
    doc = {}
    @attributes.each do|k,v|
      h = k==:text ? '#' : '-'
      doc["#{h}#{k}"] = v
    end
    @elements.each do|elem|
      doc.merge! elem.to_obj
    end
    return {@name => doc}
  end

  # XML
  def to_xml
    attrs, content = '', ''
    @attributes.each do |k,v|
      if k == :text
        content += "#{[v].flatten.join("\n")}"
      elsif k == :namespace && !v
        next
      else
        attrs += " #{k}=\"#{v}\""
      end
    end
    return "<#{@name}#{attrs}/>" if @elements.size==0 && !@attributes[:text]
    @elements.each do|e|
      content += if e.is_a?(XmlNode)
        e.to_xml
      elsif e.instance_of?(String)
        "#{e}"
      end
    end
    return "<#{@name}#{attrs}>#{content}</#{@name}>"
  end

  def pretty format, method, indent=2
    case method
    when :xml
      pretty_xml = ""
      REXML::Document.new(self.send(format), { :raw => :all }).write(pretty_xml, indent)
      return pretty_xml
    when :json
      return JSON.pretty_generate(self.send(format))
    end
  end

  def self.make_str_from xml
    text = xml
    ['&lt;','&gt;','&amp;','&apos;','&quot;'].zip(["<",">","&",%{'},%{"}]) do|xstr,str| text.gsub!(xstr,str) end
    return text
  end
  
  def self.make_xml_from string
    xml = string
    # 注意：'&'要最先被替换
    ['&','<','>',%{'},%{"}].zip(['&amp;','&lt;','&gt;','&apos;','&quot;']) do|str,xstr| xml.gsub!(str,xstr) end
    return xml
  end

  #####################################################################################################
  # attributes operation                                                                              #
  #####################################################################################################

  def add_attributes hash
    (@attributes[:text] ||= []) << hash[:text] if hash[:text]# 文本的特殊处理
    hash.delete(:text)
    @attributes.merge!(hash)
  end

  def modify_attributes hash
    add_attributes hash
  end

  def delete_attribute key
    @attributes.delete(key) unless key==:text # 元素的内容不删除
  end

  #####################################################################################################
  # content operation                                                                                 #
  #####################################################################################################

  def add_content content
    #@attributes[:text] += content
    @elements << content
  end

  def modify_content content
    @attributes[:text] = []
    @elements.delete_if{|e|e.is_a?(String)}
    @elements << content
  end

  def delete_content
    #@attributes.delete(:text)
    @elements = @elements.find_all{|c|!c.instance_of?(XmlNode)}
  end

  def add_element elem
    if elem.is_a?(XmlNode)
      @elements << elem unless @elements.include?(elem)
      @next << elem unless @next.include?(elem)
      elem.parent = self
      elem.prev << self unless elem.prev.include?(self)
    end
  end

  def search_elements &block
    return ( block ? @elements.find_all(&block) : [] )
  end

  def delete_elements &block
    elems = search_elements(&block) if block
    elems.each{|elem|@elements.delete(elem)}
    return elems
  end

  # [???] I dont know what happen
  def self.copy node
    duplicate=XmlNode.new(name: node.name, parent: nil, attributes: node.attributes)
    node.elements.map{|subnode|self.copy(subnode)}.each do|subnode|
      duplicate.add_element subnode
    end
    return duplicate
  end
end


module XmlParser
  def self.load(filepath)
    return File.exist?(filepath) ? XmlParser.parse(open(filepath){|f| f.read}) : nil
  end

  def self.parse(s)
    parser = REXML::Parsers::SAX2Parser.new(s)
    root,current = nil,nil

    parser.listen(:start_element) do |url, local, qname, attributes|
      current = XmlNode.new(parent: current, name: local, attributes: attributes)
      current.attributes[:namespace]=url
      root ||= current
    end

    parser.listen(:end_element) do |url, local, qname, attributes|
      current = current.parent
    end

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
