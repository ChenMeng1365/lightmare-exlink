
# NODE1

这是node1的描述

## NODE2a

这是node2a的描述.  
写多行也是一样的, 只做表述不影响运算

### NODE3a

<details>
  <summary>这是折叠</summary>
  这是node3a的描述
</details>

> type-a : value-a

`southbound : node1/node2a/node3a`

只有叶子节点才需要blockquote赋值, 赋值可以指定类型, 不指定类型默认使用字符串/类型推断  

## NODE2b

这是node2b的描述.  
node2b是一个列表, 有多个实例节点  

- 2b-item-1
- 2b-item-2
- 2b-item-3

只有列出成员列表时该节点才会被当作列表节点.  
如果不实例化但要被当作列表, 至少需要写成短杠接星号的格式(\- \*)

### NODE3b

这是node3b的描述.
实例化将列表元素和它的实例子元素表示出来, 并给予赋值

| NODE2b    | a2   | Leaf     |
| --------- | ---- | -------- |
| 2b-item-1 | a2-1 | > value1 |
| 2b-item-2 | a2-2 | > value2 |
| 2b-item-3 | a2-3 | > value3 |

```lm
device-b : node1/node2b/*/node3b
device-k : #/definitions/a1/a2/*/a3
```

可以使用code指定多种模型的路径, 在映射时进行选择, 异构路径的映射仍在研究中

# NODEX

这是关联, 指定与该节点语义相关的其他节点, 用路径表示
[node3a](NODE1/NODE2a/NODE3a)

# NODEY

[^nodex]这是依赖, 指定依赖节点路径,依赖是一种强关联

[^nodex]: NODEX

