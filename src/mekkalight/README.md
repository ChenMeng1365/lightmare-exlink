
# mekkalight

这是一个YANG文档的前端, 通过编写Markdown文档来实现规约映射, 接口结构构造, 实例化传值.

## RULES

我们认为遵循如下规约书写的YANG模型是一个层次扁平, 关联简单, 映射多样的Markdown文档:

- 使用h1-h6表示节点的层级, 标题即当前节点的名称. 由于标题只有6级, 所以推荐文档层级不应该超过6级.
- 文档行文的顺序决定了各节点的层级关系, 但除了引用没有必要标注的内容.
- 使用code为文档规约指定各种实现, 实现方式可以在code的class指定, 也可以在code正文中通过MAGIC-HEADER指定.
- 使用blockquote给该节点赋值, 实现实例化. 实现实例化的节点必须是叶子节点.
- 在文档中使用a指向该节点依赖的其他节点
- 使用list来为列表节点指定每一种实例化, 使用table来将所有实例化节点串联起来

## COMMAND

使用如下命令来执行Markdown文档:

```shell
ml [-x|-s] [-d|-l] [-f] FILENAME
```

- `-x` 默认以XML格式输出NETCONF消息
- `-s` 以JSON格式输出MAPPING参数
- `-d` 默认输出文档数据估值
- `-l` 输出连接存储数据估值
- `-f` 输出到同名文件, 默认不指定, 输出到标准输出

## REQUIREMENTS

```shell
gem install lightmare-exlink # command lms & lmx
gem install casetdown # caset framework
```