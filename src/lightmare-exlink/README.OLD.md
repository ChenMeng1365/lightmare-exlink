
# LIGHTMARE = EXLINK

**CODENAME := GOBLIN**

## Guide

### Yang语言词法分析

<details>
<summary><b>qliphoth词法分析器</b></summary>

使用`rose/lex(Qliphoth::Scout::Language::xiaolong)`新增规则, 对`Qliphort::Scout::Lexer`进行扩展

```ruby
require 'qliphoth/scout/lexer'

path   = '...'
tokens = File.read(path).tokenize(name: :xiaolong, path: 'lightmare-exlink/rose/lex.rb')

line_stack = tokens.inject({}) do|line_stack, token|
  ( line_stack[token.line] ||= [] ) << "#{token.name}(#{token.value})"
end

report = line_stack.keys.sort.inject([]) do|report, lineno|
  report << "[#{lineno}]"+line_stack[lineno].join(" ")  
end

puts report.join("\n")
```

</details>

### Open-API语法树结构

* 文档解析分为北向和南向两种方法, 北向面向统一接口, 南向针对不同设备厂商  
* 南北向转换的树结构模型是统一的, 以便操作  
* 北向通过swagger-editor对照yang模型编写  
* 南向通过[EagleUmlCommon](https://github.com/OpenNetworkingFoundation/EagleUmlCommon.git)转换  
* 解析使用到了树模型(`custom-core/tree`或`imdoc/XMLUtils`)

<details>
<summary><b>Tree模型导入</b></summary>

**南向树** swagger.json=>placeholder.json

```ruby
require 'custom-core/tree'
require 'lightmare-exlink/xiaolong/stree'

Dir.mkdir '../tmp' unless File.exist? '../tmp'

source = "."
Dir["#{source}/*.json"].each do|modelpath|
  begin
    pool = XiaoLong::Southbound.build modelpath, :json
    newpath = modelpath.gsub("#{source}/",'../tmp/placeholder-')
    Tree.make

    conf = []
    pool.each do|node|
      next unless node['configuration_schema'] # for zte
      conf << node.to_doc
    end
    doc = JSON.pretty_generate(conf.first)

    File.write newpath, doc
  rescue => exception
    puts "#{modelpath}: #{exception.message}"
  end
end
```

**北向树** swagger.yaml=>placeholder.json

```ruby
require 'custom-core/tree'
require 'lightmare-exlink/xiaolong/ntree'

Dir.mkdir '../tmp' unless File.exist? '../tmp'

source = "."
Dir["#{source}/*swagger*.yaml"].each do|modelpath|
  begin
    pool = XiaoLong::Northbound.build modelpath, :yaml
    newpath = modelpath.gsub(".yaml",".json").gsub("#{source}/","../tmp/placeholder-")
    Tree.make

    head = modelpath.include?('qos_') ? pool.find{|n|n.name=='qos'} : pool.first
    doc = pool.empty? ? "" : JSON.pretty_generate(head.to_doc)

    File.write newpath, doc
  rescue => exception
    puts "#{modelpath}: #{exception.message}"
  end
end
```

</details>

<details>
<summary><b>XTree模型导入</b></summary>

※ 转化的只是模型, 一般列表只包含一个节点, 使用时需要派生

**XmlNode** swagger.json/yaml=>placeholder.json

```ruby
Dir['imdoc/XMLUtils/*'].each{|mod|require mod}
require 'lightmare-exlink/xiaolong/xtree'

Dir.mkdir '../tmp' unless File.exist? '../tmp'

begin # northbound
  source = '.'
  Dir["#{source}/*swagger*.yaml"].each do|modelpath|
    begin
      pool = XiaoLong::Northbound.build_from modelpath
      newpath = modelpath.gsub(".yaml",".json").gsub("#{source}/","../tmp/placeholder-")
      head = modelpath.include?('qos_') ? pool.find{|n|n.name=='qos'} : pool.first
      doc = pool.empty? ? "" : JSON.pretty_generate({head.name=>head.to_doc})
      File.write newpath, doc
    rescue => exception
      puts "#{modelpath}: #{exception.message}"
    end
  end
end

begin # southbound
  source = "."
  Dir["#{source}/*.json"].each do|modelpath|
    begin
      pool = XiaoLong::Southbound.build_from modelpath
      newpath = modelpath.gsub("#{source}/",'../tmp/placeholder-')
      conf = []
      nodes = pool.select{|node|['configuration_schema'].include?(node.name)} # zte
      nodes.each do|node|
        conf << {node.name=>node.to_doc}
      end
      doc = JSON.pretty_generate(conf.first)
      File.write newpath, doc
    rescue => exception
      puts "ERROR: #{modelpath}: #{exception.message}"
    end
  end
end
```

</details>

<details>
<summary><b>XTree模型工具</b></summary>

* **寻路**`XTree#trace`: 从指定节点进行寻路, 定位子节点, 以进行更深入的操作
* **反向寻路**`XTree#backtrace`: 从指定节点反向寻找前缀节点, 如路径不匹配则报错
* **内视**`XTree#insight`:查看节点的基本信息, 最重要的是关联文档信息(setting)
* **文档**`XTree#to_doc`: 将节点转为JSON实例, 如果节点设定有值(val), 就会被赋值
* **netconf消息**`XTree#to_netconf`: 将节点转化为NETCONF消息, 只有存在值(val)的节点才会生成消息, 无值会被跳过

* **上溯转化**`XiaoLong::metaphysic`: 将消息实例转化为节点模型, 但实例缺乏setting, 需要通过其他方法添加校验文档  
* **偏序构造**`XiaoLong::asym`: 从指定节点生成到达相对路径的节点, 如不给出指定节点, 则生成默认根节点开始派生  
* **索引表**`XiaoLong::to_index`: 将指定节点下属所有子节点的索引全部提取, 形成一个散列文档, 但实例中同级列表的不同节点的索引会覆盖, 生成时注意控制范围  

从模型文档生成树型实例

```ruby
val = lambda{|node|node.val || "NO-SET"}

# from northbound
npath = "#{$DOC}/openapi-bgp_swagger.yaml"
npool = XiaoLong::Northbound.build_from npath
nroot = npool.find{|node|node.name=='qos'}
timer_keepalive = nroot.trace "configuration/instances/*/timer/keepalive"
puts timer_keepalive.insight(:doc).join("\n")
timer_keepalive.val = 300
File.write "n.json", JSON.pretty_generate({nroot.name=>nroot.to_doc(val)})
File.write "n.xml", XMLStringChanger.pretty(nroot.to_netconf)

# from southbound
spath = "#{$DOC}/zxr10-bgp@2021-03-02.json"
spool = XiaoLong::Southbound.build_from spath
sroot = spool.find{|node|node.name=='configuration_schema'}
timer_keepalive2 = sroot.trace "bgp/bgp-instances/bgp-inst/*/bgp/timers/keepalive-interval"
puts timer_keepalive2.insight(:doc).join("\n")
timer_keepalive2.val = '300'
File.write "s.json", JSON.pretty_generate({sroot.name=>sroot.to_doc(val)})
File.write "s.xml", XMLStringChanger.pretty(sroot.to_netconf)
```

从实例数据构建树型实例

```ruby
doc = JSON.parse File.read("atom-qos-merge.json")
oroot = XiaoLong::metaphysic(doc)

# 生成links文档
links = []
oroot.to_index(links)
sheet = "["+links.map{|link|link.to_s}.join(",\n")+"]" # 做出一个原生links文档

groot = XiaoLong.gen_root
puts sheet # 原生sheet如下赋值:
[
  {"#/definitions/configuration/qos-template/diffserv-domains/*[1]/name"=>"TestSupport"},
  {"#/definitions/configuration/qos-template/diffserv-domains/*[1]/behavior-aggregations/*[1]/type"=>"8021p"},
  ...
  {"#/definitions/configuration/qos-template/diffserv-domains/*[1]/per-hop-behaviors/*[2]/type"=>"ip-dscp"},
  ...
  {"#/definitions/configuration/qos-template/diffserv-domains/*[2]/name"=>"TestUnsupport"},
  {"#/definitions/configuration/qos-template/diffserv-domains/*[2]/behavior-aggregations/*[3]/type"=>"user-priority"},
  ...
].each do|item|
  path, val = item.keys.first, item.values.first
  current = XiaoLong.asym path.sub('#/definitions/',''), groot
  current.val = val
end

# trace节点(带subname寻址)
diffserv_domains_2 = groot.trace "configuration/qos-template/diffserv-domains/*[2]"
puts diffserv_domains_2.insight(:doc).join("\n")

# backtrace节点(带subname寻址)
service_class = groot.trace "configuration/qos-template/diffserv-domains/*[1]/per-hop-behaviors/*[2]/service-class"
diffserv_domains_1 = service_class.backtrace "*[1]/per-hop-behaviors/*[2]"
puts diffserv_domains_1.insight(:doc).join("\n")

# 重新生成文档(mock should be equal atom)
File.write "mock-qos-merge.json",JSON.pretty_generate(groot.to_doc(lambda{|n|n.val}))
```

通过lm脚本编写树型实例

```ruby
#!/usr/local/bin/ruby
#FILE: lm-runner.rb
require 'easyline'

name, root, debug = ARGV[0..2]
EasyLine.translate(name: name, root: root, debug: debug)
```

```shell
./lm-runner.rb FILENAME ROOT [-d]
```

当使用`-d`选项时, 会保留link脚本用于检查

lm脚本语法: 

* 脚本为纯线性结构, 从上往下执行
* 基本语句结构为`CALL-FUNCTION ARGVS`, 意为调用某方法并传值给它; `CALL-FUNCTION`指定调用方法名, `ARGVS`指定参数值, 可以有一个或多个参数
* `$:`之后内容为注释, 不参与估值
* 使用内置函数`path`指定当前的树路径, 后续节点的路径从此设置的路径出发, 如果需要更换路径, 则重新设置`path`
* `bind`绑定变量用于列表实例化, 对于后续路径中出现`*`的列表节点, 通过绑定该值区分不同的列表, 值可以随意指定, 如果要相互区别列表, 只要保证实例值不一样即可, 没有列表实例的场合, `bind`不影响估值
* 取消列表实例化使用`unbind`, 后接一个数字指定退栈多少个binding(※`bind`添加的实例是叠加入队列/栈的, 如果`unbind`数量不匹配的话, 实例化可能会变形, 故最好要保持`bind`和`unbind`的数量一致)
* 上述内置命令默认实现在最基本版本的`EasyLine::Handler`中, 其他`CALL-FUNCTION`会被直接解析成节点路径, 在拼接当前`path`指定的路径和参与当前`bind`的列表实例后实例化, 并赋予`ARGVS`指定的值
* `ARGVS`的值默认为字符串, 对于数字和逻辑值(true/false)进行转化

实例: 

```lm
bind i1
  path #/definitions/bgp/configuration/instances/*
  local-as 9999

  bind af1
    afs/*/af-type ipv6uni
  unbind

  bind g1 p1
    peer-group/groups/*/group-name pgV6
    peer-group/groups/*/peer-type ibgp
    peer-group/groups/*/members/*/peer-address 214F:214F::214F:A
  unbind 1 $: 注意这里只退栈1个, 不推荐

  bind p2 $: 实际bind栈为[i1, g1], 加入了p2, 不推荐这种写法
    peer-group/groups/*/members/*/peer-address 214F:214F::214F:B
  unbind 2 $: 出栈时释放g1和p2, 栈只留[i1]
unbind
```

从上面也能看出, `bind`只是用于维护层次结构的一种美化手段, 也可以直接给节点列表赋值, 完全不设绑定

```lm
path #/definitions/bgp/configuration/instances/*[i1]

local-as 9999
afs/*[af1]/af-type ipv6uni

peer-group/groups/*[g1]/group-name pgV6
peer-group/groups/*[g1]/peer-type ibgp

peer-group/groups/*[g1]/members/*[p1]/peer-address 214F:214F::214F:A
peer-group/groups/*[g1]/members/*[p2]/peer-address 214F:214F::214F:B
```

生成文档: 

```json
{
  "configuration": {
    "instances": [
      {
        "local-as": "9999",
        "afs": [
          {
            "af-type": "ipv6uni"
          }
        ],
        "peer-group": {
          "groups": [
            {
              "group-name": "pgV6",
              "peer-type": "ibgp",
              "members": [
                {
                  "peer-address": "214F:214F::214F:A"
                },
                {
                  "peer-address": "214F:214F::214F:B"
                }
              ]
            }
          ]
        }
      }
    ]
  }
}
```

</details>

### Yang/Yin语法树结构

Open-API转化的YANG模型在表达各家建模意图时仍然可能存在一定的误差或描述缺失, 这里使用另一种转换方式, 先将YANG模型转换为Yin格式, 再按语法树格式进行解析

<details>
<summary><b>Yang与Yin模型的转化</b></summary>

使用pyang就能转化YANG模型到Yin模型

```shell
pyang -f yin DOCNAME.yang -o DOCNAME.yin
```

在转换过程中, 遇到依赖的模块会在当前目录中寻找, 找不到会报依赖错误, 所以转换模型是以某个设备/系统整体进行转化而不是以单个模型文件

</details>

<details>
<summary><b>模块信息遍历和定位</b></summary>

文档查询主要聚焦如下目的: 

* 给出某个设备的Yin模型文件路径用以确定来源
* 给出某个子模块的名称用以筛选
* 给出某个模型从某个节点出发遍历所有子节点的模型样貌, 并打印所有叶子节点路径
* 给出某个节点的名称和类型(可选)用以筛选, 并解析语义给出文档

```ruby
# 定位文档路径和子模块名称
base = '/home/ubuntu/workspace/doc'
dir = "#{base}/yin-huawei-ne40-v8r22"
search = 'qos'

# Dir.mkdir(dir.sub('yin-','doc-')) unless File.exist?(dir.sub('yin-','doc-'))
Dir["#{dir}/*.yin"].each do|path|
  next unless path.include?(search)
  report = []
  
  model = XmlParser.load(path)
  report << "<<<< #{model.name} >>>>\n\n#{model.attributes.merge("filepath" => path).map{|kv|kv.join(': ')}.join("\n")}\n"  # 摘要信息
  model.elements.each do|node|
    if YTree.in?{node.name} && (doc = ycheck!(node, node.name)) # 摘要性节点
      report << doc.to_json
    end

    if ytree?(node) # 实体节点
      # general doc:
      report += [''] + YTree.walk_path(node, tags: ['flow-queues', 'normal']) # 遍历特定字段的叶子节点组成的路径
      report += [''] + YTree.walk_doc(node,'normal-mode-queue','list') # 寻找特定名称和类型的节点并文档化

      # specific doc:
      prefix = 'zxr10-bgp/configuration/bgp/bgp-instances/bgp-inst/*/'
      match  = 'address-family-evpn/neighbor-evpn/neighbor-group/neighbor-peergroup/*/nh-unchanged/next-hop-unchanged-all/next-hop-unchanged-all'
      list = YTree.walk_pathdoc(node, match: match, prefix: prefix, doc: :yes).map{|n|n[1..-1].join("\n")}
      report += ["\n#{prefix ? %Q{common prefix: #{prefix}} : '' }\n"]+list
    end

    # File.write "#{path.sub('yin-','doc-').sub('.yin','.txt')}", report.join("\n\n")
  end
  report << Array.new(64,"<").join+Array.new(64,">").join
  File.write '/home/ubuntu/workspace/dev/checkout.txt', report.join("\n")
end
```

综合实现了一个带各种参数的REST-API查询服务及使用范例(包含YTree双向和XTree北向, 文档路径请按设定自行修改和配置), 详见`examples/puma-doc`  
本地版本参看`examples/local-query`

</details>

## Changelog

**Modules**

<details>
<summary><b>Rose</b></summary>

> 0.1.0 ~> 添加了YANG字符集检测规则

</details>

<details>
<summary><b>XiaoLong</b></summary>

> **[Xiaolong]**  
> 0.1.0 ~> 以`custom-core/tree`为基础构建文档树结构  
> 0.2.0 ~> 实现了南向树`stree`和北向树`ntree`两种文档结构  
> 0.3.0 ~> 增加了支持`$ref`和`property`节点名称不同的情况, 现在节点可以任意命名  
> 0.4.0 ~> 增加了`xtree`使用XML模型解析YANG模型的Open-API文档  
> 0.5.0 ~> 分离了南北向模块的相同功能`to_doc`的代码, 并新增了`trace`和`to_netconf`功能  
> 0.6.0 ~> 统一了`xtree`实现,南北向现在生成相同的节点模型, 并新增了`to_index`和`metaphysic`方法  
> 0.7.0 ~> 新增了`backtrace`和`asym`功能, README重新排版  
> 0.7.2 ~> 修改了`to_index`表现形式, 现在可以传入列表来避免散列键重复; 修复了`insight`中根结点前缀nil输出报错  
> 0.8.0 ~> 增加了`subname`给列表节点的子项用作线索, 修改了`asym`生成方式, 现在可以正常生成带线索(`subname`)的子项节点了  
> 0.9.0 ~> 增加了`EasyLine`用来书写lm脚本, 通过lm脚本, 将一个一维的路径赋值转化为一个树型结构, 对于多个路径赋值构建实例文档  
> 0.10.0 ~> 开始根据`yin`模型进行文档解析和数据转化, 制作`ytree`, 实现了多种简单语义节点的检查解析`YCheck`; 修正了`EasyLine`中不太方便的后缀问题, 提供了一个脚本化工具的范例在DATA中  
> 0.11.0 ~> 增加了大量yang词法解析到`ycheck`中, 更新了`YTree.walk_pathdoc`, 增加了`YTree.debug`, 增加了`examples/puma-doc`; TODO: 中兴华为自有扩展放入`ycheck-ext`待解析  
> 0.11.1 ~> 修正了gemspec中引入顺序引起的`xtree#Xiaolong#Northbound#load_from`载入文件错误, 回退了`ytree#walk`各方法中`uses`错误拼接  
> 0.12.0 ~> 更新了`puma-doc`, 全部使用`ytree`新接口进行查询, 对应`ytree#walk_fulldoc`, 可以关联`uses`子句依赖节点; 准备了本地查询脚本`local-query`  
> 0.12.4 ~> 增加了`YTree.list`中`case`节点声明;修正了`ycheck`中`when`节点子句和关键字`when`的命名冲突;修正了`walk_pathdoc`和`walk_fulldoc`中`option[:prefix]`为nil时不应做匹配的处理;修正了`puma-doc`和`walk_fulldoc`中`option[:typepath]`, `option[:nspath]`和`option[:term]`的默认值设置, 修改了`option[:term]`语义, 增加了`option[:leaf]`选项;增加了`<choice>A/<case>B/C`在`option[:typepath]==false`时省略的处理(※存在问题1)  

</details>

**CHECKPOINT**

<details>
<summary><b>南北向树结构的差异</b></summary>

v0.2.0~0.3.0

南北向的结构主要差异在于南向是全嵌套结构, 很少使用`$ref`引用, 肥肠适合递归解析  
北向则大量是`$ref`, 多级嵌套较少, 解析北向树也是基于嵌套不多进行的(如果嵌套超过二级, 则很可能会漏掉子节点结构)

v0.5.0

~~基于`XMLUtils#XmlNode`的`XTree`对于南北向实现是同一套模型不同的行为实现~~  
~~南北向XTree差异集中在List(Array).items模型的建模上~~  
~~默认列表节点的名称为`*`, 类型为`list`~~  
~~南向的List是一个实体节点指向一个列表节点, 列表节点派生多个子节点(`attributes[subname]`), 逻辑关系是`ParentNode --(property)--> Node.elements[0] --> List.attributes{subname=>subnode}`~~  
~~北向的List是一个列表节点指向一个实体节点, 实体节点派生多个子节点(`attributes[subname]`), 逻辑关系是`ParentNode --(property)--> List.elements[0] --> Node.attributes{subname=>subnode}`~~  
~~呃………………~~  
~~差别就在于,由于List的名称为`*`, build时做了一定的特殊处理,北向index中单纯的`*`不会显示给实体节点,实际的列表节点经过时为`Node*`, 所以index中的`*`序列是早于实体节点的, 但列表节点(index为`.../*`)不会侵染到实体节点(index为`.../Node*`)的路径上(注意二者的`route`)~~  
~~由此导致的差别之二就是`Parent.attributes[property]`要小心了, 不要找错节点, 并因此导致南北向`to_doc`,`to_netconf`,`trace`功能都需要单独定制(但考虑到南北向本身都有不遵守对方约定变更的可能, 说不上二者谁可以为准)~~  
~~`trace`对于经过列表节点来说, 南向的路径是一一对应的(包括`*`), 而北向则是相反的(经过命名为`List/*`的列表时, 实际上先经过`*`节点, 再经过`List`实体节点), 当然由于北向的index做了特殊处理, `List`的index命名为`List*`并合二为一, 所以依然可以按照南向的写法书写和读取~~  

v0.6.0

消除了南北向模型的差异,现在都使用同一套模型结构  
重点仍然是列表节点的设计:  
`ParentNode --(property)--> ListNode.elements[n] --> AnonymousListItemNode.attributes{subname=>SubNode}`

</details>


<details>
<summary><b>typepath选项的处理</b></summary>

v0.12.4

`option[:typepath]`在为true和false时,表现上有一点差异需要注意:  
(1)值为true时, 表示路径需要节点类型参与筛选, 此时正常列举所有节点  
(2)值为false时, 表示路径不需要节点类型参与筛选, 此时除了路径上的类型省略, 还会省略参与计算的节点本身, 诸如`<...>O/<choice>A/<case>B/<...>C`会变成`O/C`, 而`<choice>A`和`<case>B`也不会保留在筛选节点中(如果是关联查询的节点则有可能保留)

第二种情况还有一种特殊情况: case节点被省略后, 其内容如果仅有`uses`则会一并被忽略, 想看`case`下的`uses`需要开启`option[:typepath]`  
`option[:typepath]`和`option[:type]`一个是在筛选时处理, 一个是在打印时处理, 而无论是否打印都不会改变筛选的处理结果

</details>