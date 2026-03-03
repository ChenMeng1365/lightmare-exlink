
# Qliphoth

[Apo-]Qliphort

## Scout

a linear-lexing scanner

直接定义扩展模块

```ruby
lexer = Qliphort::Scout.define do
  token WORD:  /^\.$/
  # ...
end

tokens = lexer.analyze do 
  from_string 'anything talk' # or from_file 'anything.talk'
end
p tokens.map{|t|t.to_a}
```

引入外部扩展

将解析模块放在`qliphoth/scout`目录之下,对`Qliphort::Scout::Language`模块扩展,使用`Qliphort::Scout::Scout#use(option={name: XXX,path: XXX})`进行引用  
`name`字段即为扩展模块的方法名,不用设置路径  
`path`字段用来设置路径,不用默认路径扩展可设置外部路径

```ruby
lexer = Qliphort::Scout::Scout.new
lexer.use(name: :exlang, path: 'exlang/module.rb')

tokens = lexer.analyze do 
  from_string 'anything talk' # or from_file 'anything.talk'
end
p tokens.map{|t|p t.to_a}
```

字符串内置扩展

```ruby
'anything talk'.tokenize(name: :natural).map{|t|[t.name,t.value,t.line]}
# or
'anything talk'.tokenize(name: :exlang, path: 'exlang/module.rb').map{|t|[t.name,t.value,t.line]}
```

## Monolith

## Carrier

## Helix

## Cephalopod

## Disk

## Shell

## Stealth

## Skybase

## Towers

## Genius
