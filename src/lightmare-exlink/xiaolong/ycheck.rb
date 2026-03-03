#coding:utf-8

# 语义检查模块
module YCheck
  module_function
  
  @__ycheck_log__ = YTree.debug

  def self.list
    %Q{
      SEMANTIC-LIST:
      yang-version
      namespace
      prefix
      import
      include
      belongs-to
      organization
      contact
      description
      reference
      revision
      typedef
      type
      pattern
      range
      length
      fraction-digits
      enum
      bit
      position
      path
      base
      value-range
      case-sensitivity
      units
      identity
      key
      text
      uses
      mandatory
      leaf
      leaf-list
      container
      grouping
      augment
      refine
      list
      choice
      case
      when
      must
      config
      status
      default
      value
      max-elements
      min-elements
      presence
      unique
    }
  end

  def self.skip_list
    %w{
      rpc notification
      feature annotation
      openconfig-version origin catalog-organization regexp-posix
      task-name refine-ext
    } # 暂未考虑的节点, 包括一些内部机制
  end

  %Q{
    yang:
    yang-version number;
    yin:
    [n]yang-version [a:value]number;
  }
  def yang_version node
    node.name=='yang-version' ?
    {'yang-version' => node.attributes['value']} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    namespace "URI";
    yin:
    [n]namespace [a:uri]"URI";
  }
  def namespace node
    node.name=='namespace' ?
    {'namespace' => node.attributes['uri']} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    prefix prefix-name;
    yin:
    [n]prefix [a:value]prefix-name;
  }
  def prefix node
    node.name=='prefix' ?
    {'prefix' => node.attributes['value']} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    import module-name {
      prefix prefix-name
    }
    yin:
    [n]import [a:module]module-name {
      [s.n]prefix [s.a:value]prefix-name
    }
  }
  def import node
    short = node.elements.first ? node.elements.first.attributes['value'] : nil
    short = node.attributes['module'] unless short
    node.name=='import' ? 
    {'import' => {node.attributes['module'] => short},
     'refer'  => {short => node.attributes['module']} } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    include module-name;
    yin:
    [n]include [a:module]module-name;
  }
  def include node
    node.name=='include' ? 
    {'include' => node.attributes['module'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    belongs-to module-name {
      prefix module-prefix;
    }
    yin:
    [n]belongs-to module-name {
      prefix module-prefix;
    }
  }
  def belongs_to node
    node.name=='belongs-to' ? 
    {'belongs-to' => {node.attributes['module'] => node.elements.first.attributes['value']} } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    organization "content";
    yin:
    [n]organization [s.n=text:text]"content";
  }
  def organization node
    node.name=='organization' ? 
    {'organization' => node.elements.first.attributes[:text]} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    contact "content";
    yin:
    [n]contact [s.n=text:text]"content";
  }
  def contact node
    node.name=='contact' ? 
    {'contact' => node.elements.first.attributes[:text]} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    description "content";
    yin:
    [n]description [s.n=text:text]"content";
  }
  def description node
    node.name=='description' ? 
    {'description' => node.elements.first.attributes[:text]} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    reference "content";
    yin:
    [n]reference [s.n=text:text]"content";
  }
  def reference node
    node.name=='reference' ? 
    {'reference' => node.elements.first.attributes[:text]} :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    revision date-number {
      description
        "content";
      reference
        "content";
    }
    yin:
    [n]revision [a:date]date-number {
      [s.n]description
        [s.s.n=text:text]"content";
      [s.n]reference
      [s.s.n=text:text]"content";
    }
  }
  def revision node
    if node.name=='revision'
      des = node.elements.find{|e|e.name=='description'}
      ref = node.elements.find{|e|e.name=='reference'}
      doc = node.attributes
      des and doc.merge!(description(des))
      ref and doc.merge!(reference(ref))
      {'revision' => doc}
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    typedef custom-type {
      type base-type {
        pattern 'reg-expr';
        range "start-num..finish-num";
        length "len-num";
        fraction-digits postfix-num;
        enum atomic-value {
          description "content";
        }
      }
      units "unit-name";
      description "content";
    }
    yin:
    [n]typedef [a:name]custom-type {
      [s.n]type [s.a:name]base-type {
        pattern 'reg-expr';             ==> YCheck.pattern()
        range "start-num..finish-num";  ==> YCheck.range()
        length "len-num";               ==> YCheck.length()
        fraction-digits postfix-num;    ==> YCheck.fraction_digits()
        enum atomic-value {             ==> YCheck.enum() when base-type==enumeration
          description "content";
        }
        bit atomic-value {              ==> YCheck.bit() when base-type==bits
          description "content";
          position index;
        }
        ...
      }
      [s.n]units "unit-name";
      [s.n]description "content";
    }

  }
  def typedef node
    doc = {'typedef' => node.attributes['name']}
    type = node.elements.find{|e|e.name=='type'}
    units = node.elements.find{|e|e.name=='units'}
    desc  = node.elements.find{|e|e.name=='description'}
    type  and doc.merge!( YCheck.type(type) )
    units and doc.merge!( YCheck.units(units) )
    desc  and doc.merge!( YCheck.description(desc) )
    return doc
  end

  def type node
    if node.name=='type'
      typename = node.attributes['name']
      subsetting = {'type' => typename}
      node.elements.each do|subnode|
        signal = subnode.name
        if ycheck?(signal)
          subdoc = ycheck(subnode, signal)
          if signal=='enum'
            subsetting['enum'] ||= {}
            subsetting['enum'].merge!(subdoc['enum'])
          elsif signal=='bit'
            subsetting['bits'] ||= []
            subsetting['bits'] << subdoc
          else
            subsetting.merge!(subdoc)
          end
        else
          log = "WARN: Unknown node-type for checking: \n#{JSON.pretty_generate(subnode.to_a)}"
          @__ycheck_log__ ||= []
          @__ycheck_log__ << log
          warn log if $ytree_debug
        end
      end
      return subsetting
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    pattern 'reg-expr';
    yin: 
    [n]pattern [a.value]'reg-expr';
  }
  def pattern node
    node.name=='pattern' ? 
    {'pattern' => node.attributes['value'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    range "start-num..finish-num";
    yin: 
    [n]range [a.value]"start-num..finish-num";
  }
  def range node
    if node.name=='range'
      reg = node.attributes['value'].to_s.split('|')
      stk = []
      reg.each do|r|
        if !r.include?('..') && /^\d+$/.match(r.strip)
          stk << eval(r) 
          next
        end
        s, e = r.split('..')
        if !/^\d+$/.match(s.strip) or !(/^\d+$/.match(e.strip) || e.strip=='max')
          stk << "illegal-format-in-range:#{r}"
        else
          stk << (e.strip=='max' ? [eval(s),:max] : eval(r))
        end
      end
      {'range' => stk }
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    length "len-num";
    yin:
    [n]length [a.value]"len-num";
  }
  def length node
    if node.name=='length'
      len = node.attributes['value']
      if len.include?('..')
        s, e = len.split('..')
        return {'illegal-format-in-length' => len} unless /^\d+$/.match(s.strip) and /^\d+$/.match(e.strip)
        return {'length' => eval(len)}
      else
        return {'illegal-format-in-length' => len} unless /^["|']?\d+["|']?$/.match(len.strip)
        return {'length' => len.to_i}
      end
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    fraction-digits postfix-num;
    yin:
    fraction-digits postfix-num;
  }
  def fraction_digits node
    if node.name=='fraction-digits'
      len = node.attributes['value']
      return {'illegal-format-in-fraction-digits' => len} unless /^["|']?\d+["|']?$/.match(len.strip)
      return {'fraction-digits' => len.to_i}
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    enum atomic-value {
      description "content";
    }
    yin:
    [n]enum [a.name]atomic-value {
      description "content"; ==> YCheck.description()
    }  
  }
  def enum node
    if node.name=='enum'
      val = node.elements.find{|e|e.name=='value'}
      des = node.elements.find{|e|e.name=='description'}
      {'enum' => {node.attributes['name'] => [(val ? value(val) : nil), (des ? description(des)['description'] : "")]}}
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:

    yin:

  }
  def bit node
    if node.name=='bit'
      doc = {'bit' => node.attributes['name']}
      pos = node.elements.find{|e|e.name=='position'}
      des = node.elements.find{|e|e.name=='description'}
      pos and doc.merge!(position(pos))
      des and doc.merge!(description(des))
      return doc
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:

    yin:

  }
  def position node
    node.name=='position' ? 
    {'position' => node.attributes['value'].to_i } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:

    yin:

  }
  def path node
    node.name=='path' ? 
    {'path' => node.attributes['value'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:

    yin:

  }
  def base node
    node.name=='base' ? 
    {'base' => node.attributes['name'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:

    yin:

  }
  def value_range node
    if node.name=='value-range'
      r = node.attributes['value']
      return {'illegal-format-in-value-range' => r} unless r.include?('..')
      s, e = r.split('..')
      unless /^\d+$/.match(s.strip) and /^\d+$/.match(e.strip) and e.strip=='max'
        return {'illegal-format-in-value-range' => r}
      else
        return e.strip=='max' ? {'value-range' => [eval(s),:max]} : {'value-range' => eval(r)}
      end
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:

    yin:

  }
  def case_sensitivity node
    node.name=='case-sensitivity' ? 
    {'case-sensitivity' => node.attributes['value'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    units "unit-name";
    yin:
    [n]units [a:name]"unit-name";
  }
  def units node
    node.name=='units' ? 
    {'units' => node.attributes['name'] } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    identity item-id {
      base "base-id";
      description "content";
    }
    yin:
    [n]identity [a:name]item-id {
      [s.n]base "base-id";         ==> YCheck.base()
      [s.n]description "content";  ==> YCheck.description()
    }
  }
  def identity node
    if node.name=='identity'
      doc = {'identity' => node.attributes['name']}
      base = node.elements.find{|e|e.name=='base'}
      desc = node.elements.find{|e|e.name=='description'}
      base and doc.merge!(base(base))
      desc and doc.merge!(description(desc))
      return doc
    else
      {'mis-match' => node.name}
    end
  end

  %Q{
    yang:
    key "value";
    yin:
    [n]key [a:value]"content-split-by-space";
  }
  def key node
    node.name=='key' ? 
    {'key' => node.attributes['value'].split(' ') } :
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    <text>XXX</text>
    yin:
    [n]text [a.type]text [a.text]XXX
  }
  # 一般text应该跳过, 它往往作为其他节点的内容被解析
  def text node
    (node.name=='text' ) ?
    {"text" => node.attributes[:text]} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    uses XXX;
    yin:
    [n]uses [a.type]uses [a.name]XXX
  }
  def uses node
    (node.name=='uses' ) ?
    {"uses" => node.attributes["name"]} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    mandatory true|false;
    yin:
    [n]mandatory [a.type]mandatory [a.value]{true|false}
  }
  def mandatory node
    (node.name=='mandatory' ) ?
    {"mandatory" => eval(node.attributes["value"])} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang: 
    leaf XXX {
      ...
    }
    yin:
    [n]leaf [a.type]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def leaf node
    base = (node.name=='leaf' ) ? {"leaf" => node.attributes["name"]} : {'mis-match' => node.name}
    node.elements.each do|subnode|
      signal = subnode.name
      if ycheck?(signal)
        subdoc = ycheck(subnode, signal)
        if (subdoc.keys & base.keys).empty?
          base.merge!(subdoc)
        elsif signal=='must' # must可以叠加
          base['must'] ||= []
          base['must-description'] ||= []
          base['must'] += subdoc['must'] if subdoc['must']
          base['must-description'] += subdoc['must-description'] if subdoc['must-description']
          base.delete('must') if base['must'].empty?
          base.delete('must-description') if base['must-description'].empty?
        else
          log = "WARN: Conflict occurs when key-merging of leaf-setting:\n#{JSON.pretty_generate(node.to_a)}\n<====>\n#{JSON.pretty_generate(subnode.to_a)}\n"
          @__ycheck_log__ ||= []
          @__ycheck_log__ << log
          warn log if $ytree_debug || true
          # base.merge!(subdoc)
        end
      else
        log = "WARN: Unknown node-type for checking: #{JSON.pretty_generate(subnode.to_a)}"
        @__ycheck_log__ ||= []
        @__ycheck_log__ << log
        warn log if $ytree_debug
      end
    end
    return base
  end

  %Q{
    yang: 
    leaf-list XXX {
      ...
    }
    yin:
    [n]leaf-list [a.type]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def leaf_list node
    base = (node.name=='leaf-list' ) ? {"leaf-list" => node.attributes["name"]} : {'mis-match' => node.name}
    node.elements.each do|subnode|
      signal = subnode.name
      if ycheck?(signal)
        subdoc = ycheck(subnode, signal)
        if (subdoc.keys & base.keys).empty?
          base.merge!(subdoc)
        elsif signal=='must' # must可以叠加
          base['must'] ||= []
          base['must-description'] ||= []
          base['must'] += subdoc['must'] if subdoc['must']
          base['must-description'] += subdoc['must-description'] if subdoc['must-description']
          base.delete('must') if base['must'].empty?
          base.delete('must-description') if base['must-description'].empty?
        else
          log = "WARN: Conflict occurs when key-merging of leaf-setting:\n#{JSON.pretty_generate(node.to_a)}\n<====>\n#{JSON.pretty_generate(subnode.to_a)}\n"
          @__ycheck_log__ ||= []
          @__ycheck_log__ << log
          warn log if $ytree_debug || true
          # base.merge!(subdoc)
        end
      else
        log = "WARN: Unknown node-type for checking: #{JSON.pretty_generate(subnode.to_a)}"
        @__ycheck_log__ ||= []
        @__ycheck_log__ << log
        warn log if $ytree_debug
      end
    end
    return base
  end

  %Q{
    yang: 
    container XXX {
      ...
    }
    yin:
    [n]container [a.name]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def container node
    base = (node.name=='container' ) ? {"container" => node.attributes["name"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
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
    base.merge!('items'=>subitems)
    return base
  end

  %Q{
    yang: 
    grouping XXX {
      ...
    }
    yin:
    [n]grouping [a.name]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def grouping node
    base = (node.name=='grouping' ) ? {"grouping" => node.attributes["name"]} : {'mis-match' => node.name}
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
    base.merge!('items'=>subitems)
    return base
  end

  %Q{
    yang: 
    augment XXX {
      ...
    }
    yin:
    [n]augment [a.target-node]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def augment node
    base = (node.name=='augment' ) ? {"augment" => node.attributes["target-node"]} : {'mis-match' => node.name}
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
    base.merge!('items'=>subitems)
    return base
  end


  %Q{
    yang: 
    refine XXX {
      ...
    }
    yin:
    [n]refine [a.target-node]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def refine node
    base = (node.name=='refine' ) ? {"refine" => node.attributes["target-node"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
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
    base.merge!('items'=>subitems)
    return base
  end

  %Q{
    yang: 
    list XXX {
      ...
    }
    yin:
    [n]list [a.name]XXX {
      [s.n]... ====> YCheck.???()
    } 
  }
  def list node
    base = (node.name=='list' ) ? {"list" => node.attributes["name"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
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
    base.merge!('items'=>subitems)
    return base
  end

  %Q{
    yang:
    choice XXX{
      description "desc";
      case YYY {
        ...
      }
      ...
    }
    yin:
    [n]choice [a.name]XXX {
      [s.n]description [s:text]desc
      [s.n]case [s.a.name]YYY {
        ... ====> YCheck.???()
      }
      ...   ====> YCheck.???()
    }
  }
  def choice node
    base = (node.name=='choice' ) ? {"choice" => node.attributes["name"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
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
    base.merge!('items'=>subitems) if subitems.size>0
    return base
  end


  %Q{
    yang:
    case XXX {
      description "desc";
      ...
    }
    yin:
    [n]case [a.name]XXX {
      [s.n]description [s:text]desc
      ... ====> YCheck.???()
    }
  }
  def _case node
    base = (node.name=='case' ) ? {"case" => node.attributes["name"]} : {'mis-match' => node.name}
    subitems = []
    node.elements.each do|subnode|
      if subnode.name=='description'
        base.merge!(description(subnode))
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
    base.merge!('items'=>subitems) if subitems.size>0
    return base
  end

  %Q{
    yang:
    when "cond" {
      description "...";
    }
    yin:
    [n]when [a.condition]cond {
      [s.n]description "..."; ==> YCheck.description()
    }
  }
  def _when node
    base = (node.name=='when') ? {"when" => node.attributes["condition"]} : {'mis-match' => node.name}
    node.elements.each do|subnode|
      base.merge!('when-description'=>description(subnode)['description']) if subnode.name=='description'
    end
    return base
  end

  %Q{
    yang:
    must "cond" {
      description "...";
    }
    yin:
    [n]must [a.condition]cond {
      [s.n]description "..."; ==> YCheck.description()
    }
  }
  def must node
    base = (node.name=='must') ? {"must" => [node.attributes["condition"]]} : {'mis-match' => node.name}
    node.elements.each do|subnode|
      base.merge!('must-description'=>[description(subnode)['description']]) if subnode.name=='description'
    end
    return base
  end

  %Q{
    yang:
    config {true|false};
    yin:
    [n]config [a.value]{true|false}
  }
  def config node
    (node.name=='config' ) ?
    {"config" => eval(node.attributes["value"])} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    status XXX;
    yin:
    [n]status [a.value]XXX
  }
  def status node
    (node.name=='status' ) ?
    {"status" => node.attributes["value"]} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    default XXX;
    yin:
    [n]default [a.value]XXX
  }
  def default node
    val = if /^(\d+|true|false)$/.match(node.attributes["value"])
      eval(node.attributes["value"])
    elsif node.attributes["value"]=='null'
      nil
    else
      node.attributes["value"]
    end
    (node.name=='default' ) ? {"default" => val} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    value XXX;
    yin:
    [n]value [a.value]XXX
  }
  def value node
    val = if /^(\d+|true|false)$/.match(node.attributes["value"])
      eval(node.attributes["value"])
    elsif node.attributes["value"]=='null'
      nil
    else
      node.attributes["value"]
    end
    (node.name=='value' ) ? val : {'mis-match' => node.name}
  end

  %Q{
    yang:
    max-elements XXX;
    yin:
    [n]max-elements [a.value]XXX
  }
  def max_elements node
    (node.name=='max-elements' ) ?
    {"max-elements" => eval(node.attributes["value"])} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    min-elements XXX;
    yin:
    [n]min-elements [a.value]XXX
  }
  def min_elements node
    (node.name=='min-elements' ) ?
    {"min-elements" => eval(node.attributes["value"])} : 
    {'mis-match' => node.name}
  end

  %Q{
    yang:
    presence XXX;
    yin:
    [n]presence [a.value]XXX
  }
  def presence node
    (node.name=='presence' ) ? {'presence'=> node.attributes["value"]} : {'mis-match' => node.name}
  end

  %Q{
    yang:
    unique XXX;
    yin:
    [n]unique [a.tag]XXX
  }
  def unique node
    (node.name=='unique' ) ? {'unique'=> node.attributes["tag"]} : {'mis-match' => node.name}
  end

end