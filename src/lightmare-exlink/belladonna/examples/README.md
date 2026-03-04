
# README

**文档查询**

使用`puma-doc`(~~roda-doc???~~)在线进行查询, 默认使用`YTree:walk_fullpath`进行遍历(~> v0.12.0), 以前的老版本保留在`deprived-api.ru.bak`自取  
本地查询的版本`local-query.rb`, 版本同上, 直接挂文档目录, 不需要开rest-api-server

**依赖关系**

* Tree解析用到了`custom-core`和`imdoc/XMLUtils`的部分模块, 可以使用`gadget/source/scollider`将其制作成一个压缩文件引入, 或者独立关联
* Puma-Doc用到了`gem:roda`, 直接安装`gem install roda`
* 直接Lexer用到了`qliphoth/scout`的词法分析器, 暂时用不上了

**制作Gem**

参考`lightmare-make-gem.sh`, 执行后进入打包环境, `gem build lightmare-exlink.gemspec`

`custom-core`和`imdoc/XMLUtils`分别被压入了`cc-cache`和`xml-cache`

然后直接本地安装即可使用`gem install lightmare-exlink-X.X.X.gem`

**批量转换YANG模型**

参考`translate-yang-models.rb`, 支持格式: json, yaml, yin, xml, swagger, uml, tree

主要使用`pyang`, 有些格式依赖`EagleUmlCommon`插件, 但并不完美支持所有厂家, 有时候还会报语法错误(非业务领域问题), 建议自己对照报错修改对应的py脚本
