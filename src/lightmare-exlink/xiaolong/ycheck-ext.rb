#coding:utf-8

# 语义检查扩展模块
module YCheck
  module_function

  #### OPENCONFIG ####
  def self.openconfig_unilist
    %Q{
      SEMANTIC-LIST:
      extension
      argument
      yin-element
    }
  end

  %Q{
    yang:
    extension XXX {
      argument ... {
        yin-element ...;
      }
      description ...;
    }
    yin:
    [n]extension [a.name]XXX {
      [s.n]argument ...
      [s.n]description ...
    }
  }
  def extension node
    if node.name=='extension'
      doc, arglist = {}, {}
      desc = node.elements.find{|n|n.name=='description'}
      arguments = node.elements.select{|e|e.name=='argument'}
      arguments.each{|arg|arglist.merge! argument(arg)}
      doc.merge! description(desc) if desc
      doc.merge! arglist
      {'extension' => doc}
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    argument XXX {
      yin-element YYY;
    }
    yin:
    [n]argument [a.name]XXX {
      [s.n]yin-element ...
    }
  }
  def argument node
    yin = node.elements.find{|n|n.name=='yin-element'}
    node.name=='argument' ? {'argument' => {node.attributes['name']=>(yin ? yin_element(yin) : {})} } : {'mis-match' => node.name}
  end

  %Q{
    yang:
    yin-element XXX;
    yin:
    [n]yin-element [a.value]XXX
  }
  def yin_element node
    node.name=='yin-element' ? {'yin-element' => eval(node.attributes['value'])} : {'mis-match' => node.name}
  end

  #### IETF ONLY ####
  def self.ietf_unilist
    %Q{
      SEMANTIC-LIST:
      if-feature
      require-instance
      default-deny-all
    }
  end

  %Q{
    yang:
    if-feature XXX;
    yin:
    [n]if-feature [a.n]XXX
  }
  def if_feature node
    node.name=='if-feature' ? {'if-feature' => node.attributes['name']} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    require-instance XXX;
    yin:
    [n]require-instance [a.value]XXX
  }
  def require_instance node
    node.name=='require-instance' ? {'require-instance' => eval(node.attributes['value'])} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    default-deny-all;
    yin:
    [n]default-deny-all
  }
  def default_deny_all node
    node.name=='default-deny-all' ? {'default-deny-all' => true} : {'mis-match' => node.name}
  end

  #### ZTE ONLY ####
  def self.zte_unilist
    %Q{
      SEMANTIC-LIST:
      revise-date
    }
  end

  %Q{
    yang:
    revise-date date-number;
    yin:
    [n]revise-date [a:date]date-number
  }
  def revise_date node
    node.name=='revise-date' ? {'revise-date' => node.attributes['date']} : {'mis-match' => node.name}
  end

  #### Huawei ONLY ####
  def self.huawei_unilist
    %Q{
      SEMANTIC-LIST:
      operation-exclude
      generated-by
      default-value
      dynamic-default
      support-filter
      filter
      value-meaning
      item
      meaning
    }
  end

  %Q{
    yang:
    operation-exclude XXX {
      description "...";
    }
    yin:
    [n]operation-exclude [a.value]XXX {
      [s.n]description {...}
    }
  }
  def operation_exclude node
    if node.name=='operation-exclude'
      des = node.elements.find{|e|e.name=='description'}
      doc = {'operation-exclude'=>node.attributes['value']}
      doc.merge!(description(des)) if des
      doc
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    generated-by value {
      when "...";
      ...;
      description "...";
    }
    yin:
    [n]generated-by [a.value]... {
      [s.n]... ====> YCheck.???()
    }
  }
  def generated_by node
    base = (node.name=='generated-by' ) ? {"generated-by" => node.attributes["value"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
        next
      end
      if subnode.name=='when'
        base.merge!(_when(subnode))
        next
      end
      signal = subnode.name
      if ycheck?(signal)
        subdoc = ycheck(subnode, signal)
        subitems << subdoc
      else
        log = "WARN: Unknown node-type for checking: #{JSON.pretty_generate(subnode.to_a)}"
        @__ycheck_log__ ||= []
        @__ycheck_log__ << log
        warn log if $ytree_debug
      end
    end
    base.merge!('items'=>subitems) unless subitems.empty?
    return base
  end

  %Q{
    yang:
    default-value "XXX" {
      when "...";
      description "...";
    }
    yin:
    [n]default-value [a.value]XXX {
      [s.n]when
      [s.n]description
    }
  }
  def default_value node
    if node.name=='default-value'
      cnd = node.elements.find{|e|e.name=='when'}
      des = node.elements.find{|e|e.name=='description'}
      doc = {'default-value' => node.attributes['value']}
      doc.merge! _when(cnd) if cnd
      doc.merge! description(des) if des
      doc
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    dynamic-default {
      default-value "XXX" {
        ...
      }
      ...
    }
    yin:
    [n]dynamic-default {
      [s.n]default-value [s.a.value]XXX {...}
      ...
    }
  }
  def dynamic_default node
    if node.name=='dynamic-default'
      dvs = node.elements.select{|e|e.name=='default-value'}
      doc = dvs.map{|dv|default_value(dv)}
      {'dynamic-default'=> doc}
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    support-filter "bool";
    yin:
    [n]support-filter [a.value]bool
  }
  def support_filter node
    node.name=='support-filter' ? {'support-filter' => eval(node.attributes['value'])} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    filter "...";
    yin:
    [n]filter [a.value]...
  }
  def filter node
    node.name=='filter' ? {'filter' => node.attributes['value']} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    value-meaning {
      item XXX {
        ext:meaning YYY;
      }
      ...
    }
    yin:
    [n]value-meaning {
      [s.n]item [s.a.value]XXX {
        [s.s.n]meaning [s.s.a.value]YYY
      }
      ...
    }
  }
  def value_meaning node
    if node.name=='value-meaning'
      items = node.elements.select{|e|e.name=='item'}
      doc = {}
      items.each{|i|doc.merge!(item(i))}
      {'value-meaning' => doc}
    else
      {'mis-match' => node.name}
    end
  end
  def item node
    if node.name=='item'
      des = node.elements.find{|e|e.name=='meaning'}
      # doc = {'item'=>node.attributes['value']}
      # doc.merge!(meaning(des)) if des
      # doc
      {node.attributes['value'] => (des ? meaning(des) : nil) }
    else
      {'mis-match' => node.name}
    end
  end
  def meaning node
    # node.name=='meaning' ? {'meaning' => node.attributes['value']} : {'mis-match' => node.name}
    node.name=='meaning' ? node.attributes['value'] : {'mis-match' => node.name}
  end
end
