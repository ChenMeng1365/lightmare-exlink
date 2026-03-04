#coding:utf-8

class Linkdown
  attr_reader :base, :ext
  attr_accessor :next, :prev

  def initialize option={}
    @base = option[:container]
    @ext = option[:setting] || {}
    @next = option[:next] || []
    @prev = option[:prev]
  end

  def set flag, value
    flag==:container and @base = value
    flag==:setting   and @ext  = value if value.instance_of?(Hash)
  end

  def add setting
    @ext ||= {}
    @ext.merge! setting if setting.instance_of?(Hash)
    setting
  end

  def next= alt
    @next ||= []
    @next << alt unless @next.include? alt
    alt.prev = self if alt.instance_of?(Linkdown) && alt.prev!=self
  end

  def prev= alt
    @prev = alt
    (alt.next ||= [];alt.next << self) if alt.instance_of?(Linkdown) && !alt.next.include?(self)
  end

  def path list=[]
    list.unshift self
    if @prev
      return @prev.path list
    else
      return list
    end
  end

  #####################################################################################
  # linkdown                                                                          #
  #####################################################################################
  def self.analysis doc
    title, attr, content = doc
    if %w{h1 h2 h3 h4 h5 h6}.include? title
      hx = Linkdown.new(container: title)
      hx.add depth: title[1].to_i, name: content.first
      return hx

    elsif 'blockquote'==title
      sub_para, sub_attr, sub_contents = content.first
      type, value = sub_contents.first.split(' : ')
      value, type = type, 'String' unless value
      return {instance: {type=>value}}
    elsif 'table'==title
      thead, tbody = content
      heads = thead.last.last.last.map{|th|th.last.last}
      rows = tbody.last.map{|tr|tr.last.map{|td|td.last.last}}
      rows.unshift heads
      return {instance: rows}

    elsif 'code'==title
      type, value = content.first.split(' : ')
      value, type = type, '*' unless value
      return {formula: {type=>value}}
    elsif 'pre'==title
      klass = content.first[1]['class']
      klass = '*' unless klass
      list = {}
      content.first[-1].last.split("\n").each do|i|
        type, value = i.split(' : ')
        value, type = type, '*' unless value
        list[type] = value
      end
      return {interpreter: klass, formula: list}

    elsif 'ul'==title
      list = []
      content.each do|li|
        list << li.last.first if li.first=='li'
      end
      return {list: list}

    elsif 'a'==title
      node = attr['href']
      type = content.last[0]=='^' ? 'require' : 'link'
      name = content.last[0]=='^' ? content.last[1..-1] : content.last
      return {link: node, 'link-type': type, 'link-name': name}

    elsif 'p'==title
      text,child = [],[]
      content.each do|c|
        text << c if c.instance_of?(String)
        child << self.analysis(c) if c.instance_of?(Array)
      end
      return [{desc: text.join("\n")}]+child.compact
    elsif 'details'==title
      text,head = [],''
      content.each do|c|
        text << c if c.instance_of?(String)
        if c.instance_of?(Array)
          summary, att, heads = c
          head = heads.first if summary=='summary'
        end
      end
      return {desc: "#{head}>> #{text.join("\n")}"}
    elsif 'br'==title
      return nil
    else
      return doc
    end
  end

  def self.archieve docs # doc :: XmlNode#to_a
    return docs.inject([]) do|nods, doc|
      if doc.instance_of? Linkdown
        nods << doc
      else
        if doc[:desc]
          nods.last.ext[:desc] ||= ''
          nods.last.ext[:desc] += "\n"+doc[:desc]
          nods.last.ext[:desc].strip!
          other = doc.clone
          other.delete :desc
          nods.last.add other
        else
          nods.last.add doc
        end
      end
      nods
    end
  end

  def self.make_rel nods, name='local'
    root = Linkdown.new(setting: {name: name, depth: 0})
    nods.each_with_index do|nod,idx|
      if nod.ext[:depth]==1
        nod.prev = root
      end
      if nod.ext[:depth]>1
        i=idx-1;prev = nods[i]
        while prev.ext[:depth] >= nod.ext[:depth]
          i -= 1
          prev = nods[i]
          break if i<0
        end
        nod.prev = i<0 ? root : prev
      end
    end
    return :ok, nods
  end

  def self.make_doc name
    cd = CasetDown.load("#{name}.md")
    docs = cd[:src].stack.map{|n| Linkdown.analysis(n.to_a)}.flatten(1).compact
    nods = Linkdown.archieve docs
    Linkdown.make_rel nods,name
    return nods
  end

  def self.level_path nod
    nod.path.map{|d|d.ext[:name]}.join('/')
  end

  def self.normal_path nod
    nod.path.map{|d|d.ext[:list] ? d.ext[:name]+'/*' : d.ext[:name]}.join('/')
  end

  def self.eval_path nod, path
    if !nod.ext[:instance]
      nil
    elsif nod.ext[:instance].instance_of?(Hash)
      "#{path} #{nod.ext[:instance].values.last}"
    elsif nod.ext[:instance].instance_of?(Array) && nod.ext[:instance].first.instance_of?(Array)
      head = nod.ext[:instance][0]
      inst = nod.ext[:instance][1..-1].inject([]) do|inst, once|
        tempath = path.clone
        once.each_with_index do|text, index|
          tempath = tempath.sub(head[index]+'/*', head[index]+"/*[#{text}]")
        end
        value = once[-1][0]=='>' ? once[-1][1..-1] : once[-1]
        inst << [tempath, ' ', value].join
        inst
      end
    else
      nil # nothing to do for exception
    end
  end

  def self.eval nods
    nods.map do|nod|
      self.eval_path nod, self.normal_path(nod)
    end.compact.flatten
  end

  def self.evalink nods, formula='*'
    nods.map do|nod|
      next unless nod.ext[:formula]
      path = nod.ext[:formula][formula]
      unless path
        path = nod.ext[:formula].values.last
        next unless path
      end
      self.eval_path nod, path
    end.compact.flatten
  end

end
