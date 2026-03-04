
# LIGHTMARE = EXLINK

**CODENAME := PHOENIX**

## Guide

### Yang语言解释器

<details>
<summary><b>qliphoth词法分析器</b></summary>

`rose/lex`扩展了`Qliphort::Scout::Lexer`做词法分析, 对`Qliphoth::Scout::Language::xiaolong`新增规则

通过pyang可以直接转换yang文档为yin文档处理

</details>

### Open-API语法树结构

<details>
<summary><b>XTree模型</b></summary>

使用树模型来统一描述YANG模型

* 文档解析分为北向和南向两种方法, 北向面向统一接口, 南向针对不同设备厂商
* 南北向转换的树结构模型是统一的, 以便操作
* 北向通过swagger-editor对照yang模型编写
* 南向通过[EagleUmlCommon](https://github.com/OpenNetworkingFoundation/EagleUmlCommon.git)转换
* 解析使用到了树模型(`custom-core/tree`或`imdoc/XMLUtils`)

模型导入:

* **STree南向树** swagger.json=>placeholder.json
* **NTree北向树** swagger.yaml=>placeholder.json
* **XTree(XmlNode)** swagger.json/yaml=>placeholder.json

借此实现从模型文档生成树型实例和从实例数据构建树型实例等功能

模型工具:

* **寻路**`XTree#trace`: 从指定节点进行寻路, 定位子节点, 以进行更深入的操作
* **反向寻路**`XTree#backtrace`: 从指定节点反向寻找前缀节点, 如路径不匹配则报错
* **内视**`XTree#insight`:查看节点的基本信息, 最重要的是关联文档信息(setting)
* **文档**`XTree#to_doc`: 将节点转为JSON实例, 如果节点设定有值(val), 就会被赋值
* **netconf消息**`XTree#to_netconf`: 将节点转化为NETCONF消息, 只有存在值(val)的节点才会生成消息, 无值会被跳过
* **上溯转化**`XiaoLong::metaphysic`: 将消息实例转化为节点模型, 但实例缺乏setting, 需要通过其他方法添加校验文档
* **偏序构造**`XiaoLong::asym`: 从指定节点生成到达相对路径的节点, 如不给出指定节点, 则生成默认根节点开始派生
* **索引表**`XiaoLong::to_index`: 将指定节点下属所有子节点的索引全部提取, 形成一个散列文档, 但实例中同级列表的不同节点的索引会覆盖, 生成时注意控制范围

</details>

<details>
<summary><b>Lm脚本</b></summary>

为了方便实例数据转换为模型结构, 使用偏序构造的方式来生成实例的树型解构  

转换工具参看`example/lm-runner`, 在命令末尾追加`-d`选项时, 会保留link脚本用于检查

语法及实现:

* 脚本是通过`XiaoLong::asym`来实现偏序构造, 完成了内置命令的最小实现`EasyLine::Handler`
* 脚本为纯线性结构, 从上往下执行
* 基本语句结构为`CALL-FUNCTION ARGVS`, 意为调用某方法并传值给它; `CALL-FUNCTION`指定调用方法名, `ARGVS`指定参数值, 可以有一个或多个参数
* `CALL-FUNCTION`会被直接解析成节点路径, 在拼接当前`path`指定的路径和参与当前`bind`的列表实例后实例化, 并赋予`ARGVS`指定的值
* `ARGVS`的值默认为字符串, 对于数字和逻辑值(true/false)进行转化
* 使用内置函数`path`指定当前的树路径, 后续节点的路径从此设置的路径出发, 如果需要更换路径, 则重新设置`path`
* `bind`绑定变量用于列表实例化, 对于后续路径中出现`*`的列表节点, 通过绑定该值区分不同的列表, 值可以随意指定, 如果要相互区别列表, 只要保证实例值不一样即可, 没有列表实例的场合, `bind`不影响估值
* 取消列表实例化使用`unbind`, 后接一个数字指定退栈多少个binding(※`bind`添加的实例是叠加入队列/栈的, 如果`unbind`数量不匹配的话, 实例化可能会变形, 故最好要保持`bind`和`unbind`的数量一致)
* `bind`只是用于维护层次结构的一种美化手段, 也可以直接给节点列表赋值, 完全不设绑定(语义自维护)
* `$:`之后行内内容为注释, 不参与估值

</details>

### Yang/Yin语法树结构

<details>
<summary><b>Yang↔Yin模型转换</b></summary>

Open-API转化的YANG模型在表达各家建模意图时仍存在一定的误差或描述缺失, 这里使用另一种转换方式, 先将YANG模型转换为Yin格式, 再按语法树格式进行解析

使用pyang就能转化YANG模型到Yin模型`pyang -f yin DOCNAME.yang -o DOCNAME.yin`  
在转换中遇到依赖的模块会在当前目录中寻找, 找不到会报依赖错误, 所以需要以某个设备/系统整体的文档集进行转化而不是以单个模型文件转换

文档查询应聚焦如下目标:

* 给出某个设备的Yin模型文件路径用以确定来源
* 给出某个子模块的名称用以筛选
* 给出某个模型从某个节点出发遍历所有子节点的模型样貌, 并打印所有叶子节点路径
* 给出某个节点的名称和类型(可选)用以筛选, 并解析语义给出文档

可以通过包装`YTree::walk`来定制新的查询方法, 构建模型和实例的结构关系

REST-API查询服务范例参看`examples/puma-doc`, 本地查询范例参看`examples/local-query`

</details>

## Changelog

<details>
<summary><b>版本更新</b></summary>

旧版本细节请查询[README.OLD.md#Changelog](README.OLD.md#Changelog)

> 1.0.0 ~> 实现了统一的`xtree`, 可以解析满足OpenAPI结构的南北向模型, `xtree`具备`to_doc`, `trace`, `to_netconf`, `to_index`, `metaphysic`, `asym`, `insight`等功能; 实现了`EasyLine`书写lm脚本, 将一维路径赋值转化为树型结构, 构建偏序实例文档; 实现了`ytree`解析满足OpenConfig和ietf的规范的YANG模型文档解析, 支持华为(v8r22)中兴(v5.00.10)路由器设备文档解析, 开放查询定制`walk`  
> 1.1.0 ~> 增加了`easyline`的多行注释, 现在可以把整段cli shell注释到lm中; `YTree.walk_fulldoc`增加了`seltype`和`seltag`查询选项, 对节点类型和摘要进行筛选; 修正了`YTree.walk_fulldoc`中对`config false`摘要的错误判断; `puma-doc`增加了`seltype`和`seltag`查询选项以及匹配多查询模块`submod`字段  
> 1.2.0 ~> `YTree.walk_fulldoc`增加了`child`选项, 可以查询直接下级节点(好像没什么用); 增加了`YTree.walk_linkdoc`, 在`YTree.walk_fulldoc`基础上将`uses`引入实体(但下属非grouping节点不展开, grouping展开三次), 开启`option[:linkref]`性能大降(这并不是最好的解决办法); 修正了`Ycheck.import`表述; `YTree.walk_fulldoc`和`YTree.walk_linkdoc`处理流重构, 一塌糊涂...  
> 1.3.0 ~> 开始重构...将工程转化为相对规整的GEM...增加了bin脚本工具到schnee...移动examples和deprived文档到belladonna...rose扩展了XmlNode,不再移植引用...xiaolong开始追加behavior...  
> 1.4.0 ~> 重写`rose/ic-xml`作文档解析; 定义了基于`prev`/`next`的实体化连接查找方法`seek`(对标基于`parent`/`elements`的`walk`); 新增`YBehave`用于解释`uses`,`import`,`include`,`belongs-to`四个子句的结构化涵义, XML树模型转为图模型; 新增`augment`的解释(仍有一些问题关于建立实体化连接`prev`/`next`: 性能和不准确问题), 使用多种路径表述匹配来寻找尽可能接近的端末节点; 简化了查询案例`belladonna/seek-query`  
> 1.4.1 ~> 修改了README.md文字表述, 命令行工具ys的参数设置; 修改`seek_path`中巡径保留grouping的问题, 当使用`option: - type`时, grouping保留, 其他场合消失  
> 1.4.2 ~> 增加了`lm`多模块拼接, 使用`module`关键字指定模块名称, 替换路径中顶层模块名; 修改了`lm`参数序列, 现在可以自有排序参数, 使用`head=`指定模块名(如果没有模块名的话); `YBehave.seek_path`修正了`leaf-list`筛选遗漏; `YBehave`关于`warn`的一些小改动  
> 1.4.3 ~> 增加了`import`的`YBehave.make_reference`  
> 1.5.0 ~> `Easyline::Handler#unbind`现在可以自动退栈绑定变量的数目而不用人工指定; `Easyline::source`加入`end`关键字修饰(仅为边界, 不起任何实质意义)  
> 1.6.0 ~> 增加了`Easyline::lm`的XML格式化功能和`Easyline::lmx`命令, 现在可以定制出NETCONF格式数据了(格式不好看)  
> 1.6.1 ~> 修正了`Easyline::lm`的GLOBAL错误  
> 1.7.0 ~> `XMLUtils::XmlNode`伴随式更新, `:namespace`文档化调整; 增加了exlink的python版本`Nikos`  

</details>
